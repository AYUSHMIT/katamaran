(******************************************************************************)
(* Copyright (c) 2019 Steven Keuchel                                          *)
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

From Coq Require
     Vector.

From MicroSail Require Import
     Notation
     Sep.Logic
     Syntax.

From Equations Require Import
     Equations.

Import CtxNotations.
Import EnvNotations.

Set Implicit Arguments.

Module Type AssertionKit
       (termkit : TermKit)
       (Export progkit : ProgramKit termkit).

  (* Predicate names. *)
  Parameter Inline 𝑷  : Set.
  (* Predicate field types. *)
  Parameter Inline 𝑷_Ty : 𝑷 -> Ctx Ty.
  Declare Instance 𝑷_eq_dec : EqDec 𝑷.

End AssertionKit.

Module Assertions
       (termkit : TermKit)
       (progkit : ProgramKit termkit)
       (Export assertkit : AssertionKit termkit progkit).

  Inductive Formula (Σ : LCtx) : Type :=
  | formula_bool (t : Term Σ ty_bool)
  | formula_prop {Σ'} (ζ : Sub Σ' Σ) (P : abstract_named Lit Σ' Prop)
  | formula_eq (σ : Ty) (t1 t2 : Term Σ σ)
  | formula_neq (σ : Ty) (t1 t2 : Term Σ σ).
  Arguments formula_bool {_} t.

  Equations(noeqns) formula_eqs {Δ : PCtx} {Σ : LCtx}
    (δ δ' : NamedEnv (Term Σ) Δ) : list (Formula Σ) :=
    formula_eqs env_nil          env_nil            := nil;
    formula_eqs (env_snoc δ _ t) (env_snoc δ' _ t') :=
      formula_eq t t' :: formula_eqs δ δ'.

  Instance sub_formula : Subst Formula :=
    fun Σ1 Σ2 ζ fml =>
      match fml with
      | formula_bool t    => formula_bool (subst ζ t)
      | formula_prop ζ' P => formula_prop (subst ζ ζ') P
      | formula_eq t1 t2  => formula_eq (subst ζ t1) (subst ζ t2)
      | formula_neq t1 t2 => formula_neq (subst ζ t1) (subst ζ t2)
      end.

  Instance substlaws_formula : SubstLaws Formula.
  Proof.
    constructor.
    { intros ? []; cbn; f_equal; apply subst_sub_id. }
    { intros ? ? ? ? ? []; cbn; f_equal; apply subst_sub_comp. }
  Qed.

  Definition inst_formula {Σ} (ι : SymInstance Σ) (fml : Formula Σ) : Prop :=
    match fml with
    | formula_bool t    => is_true (inst (A := Lit ty_bool) ι t)
    | formula_prop ζ P  => uncurry_named P (inst ι ζ)
    | formula_eq t1 t2  => inst ι t1 =  inst ι t2
    | formula_neq t1 t2 => inst ι t1 <> inst ι t2
    end.

  Instance instantiate_formula : Inst Formula Prop :=
    {| inst Σ := inst_formula;
       lift Σ P := formula_prop env_nil P
    |}.

  Instance instantiate_formula_laws : InstLaws Formula Prop.
  Proof.
    constructor; auto.
    intros Σ Σ' ζ ι t.
    induction t.
    - unfold subst, sub_formula, inst at 1 2, instantiate_formula, inst_formula.
      f_equal.
      eauto using inst_subst.
    - unfold subst, sub_formula, inst at 1 2, instantiate_formula, inst_formula.
      f_equal.
      eapply inst_subst.
    - unfold subst, sub_formula, inst at 1 2, instantiate_formula, inst_formula.
      f_equal; eapply inst_subst.
    - unfold subst, sub_formula, inst at 1 2, instantiate_formula, inst_formula.
      repeat f_equal; eapply inst_subst.
  Qed.

  Inductive Chunk (Σ : LCtx) : Type :=
  | chunk_user   (p : 𝑷) (ts : Env (Term Σ) (𝑷_Ty p))
  | chunk_ptsreg {σ : Ty} (r : 𝑹𝑬𝑮 σ) (t : Term Σ σ).
  Arguments chunk_user [_] _ _.

  Inductive Assertion (Σ : LCtx) : Type :=
  | asn_formula (fml : Formula Σ)
  | asn_chunk (c : Chunk Σ)
  | asn_if   (b : Term Σ ty_bool) (a1 a2 : Assertion Σ)
  | asn_match_enum (E : 𝑬) (k : Term Σ (ty_enum E)) (alts : forall (K : 𝑬𝑲 E), Assertion Σ)
  | asn_match_sum (σ τ : Ty) (s : Term Σ (ty_sum σ τ)) (xl : 𝑺) (alt_inl : Assertion (Σ ▻ (xl :: σ))) (xr : 𝑺) (alt_inr : Assertion (Σ ▻ (xr :: τ)))
  | asn_match_list
      {σ : Ty} (s : Term Σ (ty_list σ)) (alt_nil : Assertion Σ) (xh xt : 𝑺)
      (alt_cons : Assertion (Σ ▻ xh∶σ ▻ xt∶ty_list σ))
  | asn_match_pair
      {σ1 σ2 : Ty} (s : Term Σ (ty_prod σ1 σ2))
      (xl xr : 𝑺) (rhs : Assertion (Σ ▻ xl∶σ1 ▻ xr∶σ2))
  | asn_match_tuple
      {σs : Ctx Ty} {Δ : LCtx} (s : Term Σ (ty_tuple σs))
      (p : TuplePat σs Δ) (rhs : Assertion (Σ ▻▻ Δ))
  | asn_match_record
      {R : 𝑹} {Δ : LCtx} (s : Term Σ (ty_record R))
      (p : RecordPat (𝑹𝑭_Ty R) Δ) (rhs : Assertion (Σ ▻▻ Δ))
  | asn_match_union
      {U : 𝑼} (s : Term Σ (ty_union U))
      (alt__ctx : forall (K : 𝑼𝑲 U), LCtx)
      (alt__pat : forall (K : 𝑼𝑲 U), Pattern (alt__ctx K) (𝑼𝑲_Ty K))
      (alt__rhs : forall (K : 𝑼𝑲 U), Assertion (Σ ▻▻ alt__ctx K))
  | asn_sep  (a1 a2 : Assertion Σ)
  | asn_exist (ς : 𝑺) (τ : Ty) (a : Assertion (Σ ▻ (ς :: τ))).
  Arguments asn_match_enum [_] E _ _.
  Arguments asn_match_sum [_] σ τ _ _ _.
  Arguments asn_match_list [_] {σ} s alt_nil xh xt alt_cons.
  Arguments asn_match_pair [_] {σ1 σ2} s xl xr rhs.
  Arguments asn_match_tuple [_] {σs Δ} s p rhs.
  Arguments asn_match_record [_] R {Δ} s p rhs.
  Arguments asn_match_union [_] U s alt__ctx alt__pat alt__rhs.
  Arguments asn_exist [_] _ _ _.

  Notation asn_bool b := (asn_formula (formula_bool b)).
  Notation asn_prop Σ P := (asn_formula (@formula_prop Σ Σ (sub_id Σ) P)).
  Notation asn_eq t1 t2 := (asn_formula (formula_eq t1 t2)).
  Notation asn_true := (asn_bool (term_lit ty_bool true)).
  Notation asn_false := (asn_bool (term_lit ty_bool false)).

  Instance sub_chunk : Subst Chunk :=
    fun Σ1 Σ2 ζ c =>
      match c with
      | chunk_user p ts => chunk_user p (subst ζ ts)
      | chunk_ptsreg r t => chunk_ptsreg r (subst ζ t)
      end.

  Instance substlaws_chunk : SubstLaws Chunk.
  Proof.
    constructor.
    { intros ? []; cbn; f_equal; apply subst_sub_id. }
    { intros ? ? ? ? ? []; cbn; f_equal; apply subst_sub_comp. }
  Qed.

  (* Instance sub_assertion : Subst Assertion := *)
  (*   fix sub_assertion {Σ1 Σ2} (ζ : Sub Σ1 Σ2) (a : Assertion Σ1) {struct a} : Assertion Σ2 := *)
  (*     match a with *)
  (*     | asn_formula fml => asn_formula (subst ζ fml) *)
  (*     | asn_chunk c => asn_chunk (subst ζ c) *)
  (*     | asn_if b a1 a2 => asn_if (subst ζ b) (sub_assertion ζ a1) (sub_assertion ζ a2) *)
  (*     | asn_match_enum E k alts => *)
  (*       asn_match_enum E (subst ζ k) (fun z => sub_assertion ζ (alts z)) *)
  (*     | asn_sep a1 a2 => asn_sep (sub_assertion ζ a1) (sub_assertion ζ a2) *)
  (*     | asn_exist ς τ a => asn_exist ς τ (sub_assertion (sub_up1 ζ) a) *)
  (*     end. *)

  Definition symbolic_eval_exp {Γ Σ} (δ : SymbolicLocalStore Γ Σ) :
    forall {σ} (e : Exp Γ σ), Term Σ σ :=
    fix symbolic_eval_exp {σ} (e : Exp Γ σ) : Term Σ σ :=
      match e with
      | exp_var ς                => δ ‼ ς
      | exp_lit σ l              => term_lit σ l
      | exp_binop op e1 e2       => term_binop op (symbolic_eval_exp e1) (symbolic_eval_exp e2)
      | exp_neg e                => term_neg (symbolic_eval_exp e)
      | exp_not e                => term_not (symbolic_eval_exp e)
      | exp_inl e                => term_inl (symbolic_eval_exp e)
      | exp_inr e                => term_inr (symbolic_eval_exp e)
      | exp_list es              => term_list (List.map symbolic_eval_exp es)
      | exp_bvec es              => term_bvec (Vector.map symbolic_eval_exp es)
      | exp_tuple es             => term_tuple (env_map (@symbolic_eval_exp) es)
      | @exp_projtup _ _ e n _ p => term_projtup (symbolic_eval_exp e) n (p := p)
      | exp_union E K e          => term_union E K (symbolic_eval_exp e)
      | exp_record R es          => term_record R (env_map (fun _ => symbolic_eval_exp) es)
      (* | exp_projrec e rf         => term_projrec (symbolic_eval_exp e) rf *)
      end%exp.

  Record SepContract (Δ : PCtx) (τ : Ty) : Type :=
    MkSepContract
      { sep_contract_logic_variables  : LCtx;
        sep_contract_localstore       : SymbolicLocalStore Δ sep_contract_logic_variables;
        sep_contract_precondition     : Assertion sep_contract_logic_variables;
        sep_contract_result           : 𝑺;
        sep_contract_postcondition    : Assertion (sep_contract_logic_variables ▻ (sep_contract_result :: τ));
      }.

  Arguments MkSepContract : clear implicits.

  Definition SepContractEnv : Type :=
    forall Δ τ (f : 𝑭 Δ τ), option (SepContract Δ τ).
  Definition SepContractEnvEx : Type :=
    forall Δ τ (f : 𝑭𝑿 Δ τ), SepContract Δ τ.

  Section Experimental.

    Definition sep_contract_pun_logvars (Δ : PCtx) (Σ : LCtx) : LCtx :=
      ctx_map (fun '(x::σ) => (𝑿to𝑺 x::σ)) Δ ▻▻ Σ.

    Record SepContractPun (Δ : PCtx) (τ : Ty) : Type :=
      MkSepContractPun
        { sep_contract_pun_logic_variables   : LCtx;
          sep_contract_pun_precondition      : Assertion
                                                 (sep_contract_pun_logvars
                                                    Δ sep_contract_pun_logic_variables);
          sep_contract_pun_result            : 𝑺;
          sep_contract_pun_postcondition     : Assertion
                                                 (sep_contract_pun_logvars Δ
                                                                           sep_contract_pun_logic_variables
                                                                           ▻ (sep_contract_pun_result :: τ))
        }.

    Global Arguments MkSepContractPun : clear implicits.

    Definition sep_contract_pun_to_sep_contract {Δ τ} :
      SepContractPun Δ τ -> SepContract Δ τ :=
      fun c =>
        match c with
        | MkSepContractPun _ _ Σ req result ens =>
          MkSepContract
            Δ τ
            (sep_contract_pun_logvars Δ Σ)
            (env_tabulate (fun '(x::σ) xIn =>
                             @term_var
                               (sep_contract_pun_logvars Δ Σ)
                               (𝑿to𝑺 x)
                               σ
                               (inctx_cat (inctx_map (fun '(y::τ) => (𝑿to𝑺 y::τ)) xIn) Σ)))
            req result ens
        end.

    Global Coercion sep_contract_pun_to_sep_contract : SepContractPun >-> SepContract.

  End Experimental.

  Class IHeaplet (L : Type) := {
    is_ISepLogic :> ISepLogic L;
    luser (p : 𝑷) (ts : Env Lit (𝑷_Ty p)) : L;
    lptsreg  {σ : Ty} (r : 𝑹𝑬𝑮 σ) (t : Lit σ) : L
  }.

  Arguments luser {L _} p ts.

  Section Contracts.
    Context `{Logic : IHeaplet L}.

    Definition inst_chunk {Σ} (ι : SymInstance Σ) (c : Chunk Σ) : L :=
      match c with
      | chunk_user p ts => luser p (inst ι ts)
      | chunk_ptsreg r t => lptsreg r (inst ι t)
      end.

    Fixpoint inst_assertion {Σ} (ι : SymInstance Σ) (a : Assertion Σ) : L :=
      match a with
      | asn_formula fml => !!(inst ι fml) ∧ emp
      | asn_chunk c => inst_chunk ι c
      | asn_if b a1 a2 => if inst (A := Lit ty_bool) ι b then inst_assertion ι a1 else inst_assertion ι a2
      | asn_match_enum E k alts => inst_assertion ι (alts (inst (T := fun Σ => Term Σ _) ι k))
      | asn_match_sum σ τ s xl alt_inl xr alt_inr =>
        match inst (T := fun Σ => Term Σ _) ι s with
        | inl v => inst_assertion (ι ► (xl :: σ ↦ v)) alt_inl
        | inr v => inst_assertion (ι ► (xr :: τ ↦ v)) alt_inr
        end
      | asn_match_list s alt_nil xh xt alt_cons =>
        match inst (T := fun Σ => Term Σ _) ι s with
        | nil        => inst_assertion ι alt_nil
        | cons vh vt => inst_assertion (ι ► (xh :: _ ↦ vh) ► (xt :: ty_list _ ↦ vt)) alt_cons
        end
      | asn_match_pair s xl xr rhs =>
        match inst (T := fun Σ => Term Σ _) ι s with
        | (vl,vr)    => inst_assertion (ι ► (xl :: _ ↦ vl) ► (xr :: _ ↦ vr)) rhs
        end
      | asn_match_tuple s p rhs =>
        let t := inst (T := fun Σ => Term Σ _) ι s in
        let ι' := tuple_pattern_match p t in
        inst_assertion (ι ►► ι') rhs
      | asn_match_record R s p rhs =>
        let t := inst (T := fun Σ => Term Σ _) ι s in
        let ι' := record_pattern_match p (𝑹_unfold t) in
        inst_assertion (ι ►► ι') rhs
      | asn_match_union U s alt__ctx alt__pat alt__rhs =>
        let t := inst (T := fun Σ => Term Σ _) ι s in
        let (K , v) := 𝑼_unfold t in
        let ι' := pattern_match (alt__pat K) v in
        inst_assertion (ι ►► ι') (alt__rhs K)
      | asn_sep a1 a2 => inst_assertion ι a1 ✱ inst_assertion ι a2
      | asn_exist ς τ a => ∃ (v : Lit τ), inst_assertion (ι ► (ς∶τ ↦ v)) a
    end%logic.

    Definition inst_contract_localstore {Δ τ} (c : SepContract Δ τ)
      (ι : SymInstance (sep_contract_logic_variables c)) : LocalStore Δ :=
      inst ι (sep_contract_localstore c).

    Definition inst_contract_precondition {Δ τ} (c : SepContract Δ τ)
      (ι : SymInstance (sep_contract_logic_variables c)) : L :=
      inst_assertion ι (sep_contract_precondition c).

    Definition inst_contract_postcondition {Δ τ} (c : SepContract Δ τ)
      (ι : SymInstance (sep_contract_logic_variables c)) (result : Lit τ) :  L :=
        inst_assertion (env_snoc ι (sep_contract_result c::τ) result) (sep_contract_postcondition c).

  End Contracts.

  Arguments inst_assertion {_ _ _} _ _.

End Assertions.

Module Type SymbolicContractKit
       (Import termkit : TermKit)
       (Import progkit : ProgramKit termkit)
       (Import assertkit : AssertionKit termkit progkit).

  Module Export ASS := Assertions termkit progkit assertkit.

  Parameter Inline CEnv   : SepContractEnv.
  Parameter Inline CEnvEx : SepContractEnvEx.

End SymbolicContractKit.
