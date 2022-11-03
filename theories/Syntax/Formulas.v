(******************************************************************************)
(* Copyright (c) 2020 Dominique Devriese, Georgy Lukyanov,                    *)
(*   Sander Huyghebaert, Steven Keuchel                                       *)
(* All rights reserved.                                                       *)
(*                                                                            *)
(* Redistribution and use in source and binary forms, with or without         *)
(* modification, are permitted provided that the following conditions are     *)
(* met:                                                                       *)
(*                                                                            *)
(* 1. Redistributions of source code must retain the above copyright notice,  *)
(*    this list of conditions and the following disclaimer.                   *)
(*                                                                            *)
(* 2. Redistributions in binary form must reproduce the above copyright       *)
(*    notice, this list of conditions and the following disclaimer in the     *)
(*    documentation and/or other materials provided with the distribution.    *)
(*                                                                            *)
(* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        *)
(* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED  *)
(* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR *)
(* PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR          *)
(* CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,      *)
(* EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,        *)
(* PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR         *)
(* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF     *)
(* LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING       *)
(* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         *)
(* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               *)
(******************************************************************************)

From Coq Require Import
     Bool.Bool
     Classes.Morphisms
     Classes.Morphisms_Prop
     Classes.RelationClasses
     Program.Basics
     Program.Tactics
     ZArith.

From Katamaran Require Import
     Prelude
     Notations
     Syntax.Predicates
     Base.

From Equations Require Import
     Equations.

Import ctx.notations.
Import env.notations.

Local Set Implicit Arguments.

Module Type FormulasOn
  (Import B : Base)
  (Import P : PredicateKit B).

  Local Obligation Tactic := idtac.

  Inductive Formula (Σ : LCtx) : Type :=
  | formula_user (p : 𝑷) (ts : Env (Term Σ) (𝑷_Ty p))
  | formula_bool (t : Term Σ ty.bool)
  | formula_prop {Σ'} (ζ : Sub Σ' Σ) (P : abstract_named Val Σ' Prop)
  | formula_relop {σ} (rop : bop.RelOp σ) (t1 t2 : Term Σ σ)
  | formula_true
  | formula_false
  | formula_and (F1 F2 : Formula Σ)
  | formula_or (F1 F2 : Formula Σ).
  #[global] Arguments formula_user {_} p ts.
  #[global] Arguments formula_bool {_} t.
  #[global] Arguments formula_true {_}.
  #[global] Arguments formula_false {_}.

  Definition formula_relop_neg {Σ σ} (op : RelOp σ) :
    forall (t1 t2 : Term Σ σ), Formula Σ :=
    match op with
    | bop.eq     => formula_relop bop.neq
    | bop.neq    => formula_relop bop.eq
    | bop.le     => Basics.flip (formula_relop bop.lt)
    | bop.lt     => Basics.flip (formula_relop bop.le)
    | bop.bvsle  => Basics.flip (formula_relop bop.bvslt)
    | bop.bvslt  => Basics.flip (formula_relop bop.bvsle)
    | bop.bvule  => Basics.flip (formula_relop bop.bvult)
    | bop.bvult  => Basics.flip (formula_relop bop.bvule)
    end.

  #[export] Instance sub_formula : Subst Formula :=
    fix sub_formula {Σ} fml {Σ2} ζ {struct fml} :=
      match fml with
      | formula_user p ts      => formula_user p (subst ts ζ)
      | formula_bool t         => formula_bool (subst t ζ)
      | formula_prop ζ' P      => formula_prop (subst ζ' ζ) P
      | formula_relop op t1 t2 => formula_relop op (subst t1 ζ) (subst t2 ζ)
      | formula_true           => formula_true
      | formula_false          => formula_false
      | formula_and F1 F2      => formula_and (sub_formula F1 ζ) (sub_formula F2 ζ)
      | formula_or F1 F2       => formula_or (sub_formula F1 ζ) (sub_formula F2 ζ)
      end.

  #[export] Instance substlaws_formula : SubstLaws Formula.
  Proof.
      constructor.
      { intros ? F.
        induction F; cbn; f_equal; auto; apply subst_sub_id.
      }
      { intros ? ? ? ? ? F.
        induction F; cbn; f_equal; auto; apply subst_sub_comp.
      }
  Qed.

  #[export] Instance instprop_formula : InstProp Formula :=
    fix inst_formula {Σ} (fml : Formula Σ) (ι : Valuation Σ) :=
      match fml with
      | formula_user p ts      => env.uncurry (𝑷_inst p) (inst ts ι)
      | formula_bool t         => inst (A := Val ty.bool) t ι = true
      | formula_prop ζ P       => uncurry_named P (inst ζ ι)
      | formula_relop op t1 t2 => bop.eval_relop_prop op (inst t1 ι) (inst t2 ι)
      | formula_true           => True
      | formula_false          => False
      | formula_and F1 F2      => inst_formula F1 ι /\ inst_formula F2 ι
      | formula_or F1 F2       => inst_formula F1 ι \/ inst_formula F2 ι
      end.

  #[export] Instance instprop_subst_formula : InstPropSubst Formula.
  Proof.
    intros ? ? ? ? f. induction f; cbn; rewrite ?inst_subst; auto.
    now apply and_iff_morphism. now apply or_iff_morphism.
  Qed.

  Lemma instprop_formula_relop_neg {Σ σ} (ι : Valuation Σ) (op : RelOp σ) :
    forall (t1 t2 : Term Σ σ),
      instprop (formula_relop_neg op t1 t2) ι <->
      bop.eval_relop_val op (inst t1 ι) (inst t2 ι) = false.
  Proof.
    destruct op; cbn; intros t1 t2;
      unfold bv.sle, bv.sleb, bv.slt, bv.sltb;
      unfold bv.ule, bv.uleb, bv.ult, bv.ultb;
      rewrite ?N.ltb_antisym, ?negb_true_iff, ?negb_false_iff, ?N.leb_gt, ?N.leb_le;
      auto; try Lia.lia; try (now destruct eq_dec; intuition).
  Qed.

  Import option.notations.
  #[export] Instance OccursCheckFormula : OccursCheck Formula :=
    fix oc {Σ x} xIn fml {struct fml} :=
      match fml with
      | formula_user p ts      => option.map (formula_user p) (occurs_check xIn ts)
      | formula_bool t         => option.map formula_bool (occurs_check xIn t)
      | formula_prop ζ P       => option.map (fun ζ' => formula_prop ζ' P) (occurs_check xIn ζ)
      | formula_relop op t1 t2 => t1' <- occurs_check xIn t1 ;;
                                  t2' <- occurs_check xIn t2 ;;
                                  Some (formula_relop op t1' t2')
      | formula_true           => Some formula_true
      | formula_false          => Some formula_false
      | formula_and F1 F2      => F1' <- oc xIn F1 ;;
                                  F2' <- oc xIn F2 ;;
                                  Some (formula_and F1' F2')
      | formula_or F1 F2       => F1' <- oc xIn F1 ;;
                                  F2' <- oc xIn F2 ;;
                                  Some (formula_or F1' F2')
      end.

  #[export] Instance occurs_check_laws_formula : OccursCheckLaws Formula.
  Proof. occurs_check_derive. Qed.

  Section PathCondition.

    Definition PathCondition (Σ : LCtx) : Type := Ctx (Formula Σ).

    Equations(noeqns) formula_eqs_ctx {Δ : Ctx Ty} {Σ : LCtx}
      (δ δ' : Env (Term Σ) Δ) : PathCondition Σ :=
    | env.nil,        env.nil          => ctx.nil
    | env.snoc δ _ t, env.snoc δ' _ t' =>
      ctx.snoc (formula_eqs_ctx δ δ') (formula_relop bop.eq t t').

    Equations(noeqns) formula_eqs_nctx {N : Set} {Δ : NCtx N Ty} {Σ : LCtx}
      (δ δ' : NamedEnv (Term Σ) Δ) : PathCondition Σ :=
    | env.nil,        env.nil          => ctx.nil
    | env.snoc δ _ t, env.snoc δ' _ t' =>
      ctx.snoc (formula_eqs_nctx δ δ') (formula_relop bop.eq t t').

    Lemma instprop_formula_eqs_ctx {Δ Σ} (xs ys : Env (Term Σ) Δ) ι :
      instprop (formula_eqs_ctx xs ys) ι <-> inst xs ι = inst ys ι.
    Proof.
      induction xs; env.destroy ys; cbn; [easy|].
      now rewrite IHxs, env.inversion_eq_snoc.
    Qed.

    Lemma instprop_formula_eqs_nctx {N : Set} {Δ : NCtx N Ty} {Σ} (xs ys : NamedEnv (Term Σ) Δ) ι :
      instprop (formula_eqs_nctx xs ys) ι <-> inst xs ι = inst ys ι.
    Proof.
      induction xs; env.destroy ys; cbn; [easy|].
      now rewrite IHxs, env.inversion_eq_snoc.
    Qed.

  End PathCondition.
  Bind Scope ctx_scope with PathCondition.

End FormulasOn.
