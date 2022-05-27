(******************************************************************************)
(* Copyright (c) 2020 Dominique Devriese, Sander Huyghebaert, Steven Keuchel  *)
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
     Program.Tactics
     ZArith.ZArith
     Strings.String
     Classes.Morphisms
     Classes.RelationClasses
     Classes.Morphisms_Prop
     Classes.Morphisms_Relations.
Require Import Basics.

From Coq Require Lists.List.

From Equations Require Import
     Equations.

From Katamaran Require Import
     SemiConcrete.Mutator
     Specification
     Symbolic.Mutator
     Symbolic.Solver
     Symbolic.Worlds
     Symbolic.Propositions
     Syntax.ContractDecl
     Program
     Tactics.

Set Implicit Arguments.

Import ctx.notations.
Import env.notations.

Module Soundness
  (Import B    : Base)
  (Import SIG : ProgramLogicSignature B)
  (Import SPEC : Specification B SIG)
  (Import SOLV : SolverKit B SIG SPEC)
  (Import SEMI : SemiConcrete B SIG SPEC)
  (Import SYMB : MutatorsOn B SIG SPEC SOLV).

  Import ModalNotations.
  Import SymProp.

  Class Approx (AT : TYPE) (A : Type) : Type :=
    approx :
      forall (w : World) (ι : Valuation w), (* instpc (wco w) ι -> *)
        AT w -> A -> Prop.
  Global Arguments approx {_ _ _ w} ι _ _.

  Global Instance ApproxInst {AT A} `{instA : Inst AT A} : Approx AT A :=
    fun w ι t v =>
      v = inst t ι.
  Global Arguments ApproxInst {_ _ _} w ι t v /.

  Global Instance ApproxPath : Approx 𝕊 Prop :=
    fun w ι SP P => (wsafe SP ι -> P)%type.

  Global Instance ApproxBox {AT A} `{Approx AT A} : Approx (Box AT) A :=
    fun w0 ι0 a0 a =>
      forall (w1 : World) (ω01 : w0 ⊒ w1) (ι1 : Valuation w1),
        ι0 = inst (sub_acc ω01) ι1 ->
        instpc (wco w1) ι1 ->
        approx ι1 (a0 w1 ω01) a.

  Global Instance ApproxImpl {AT A BT B} `{Approx AT A, Approx BT B} : Approx (Impl AT BT) (A -> B) :=
    fun w ι fs fc =>
      forall (ta : AT w) (a : A),
        approx ι ta a ->
        approx ι (fs ta) (fc a).

  Global Instance ApproxForall {𝑲 : Set} {AT : forall K : 𝑲, TYPE} {A : forall K : 𝑲, Type} {apxA : forall K, Approx (AT K) (A K)} :
    Approx (@Forall 𝑲 AT) (forall K : 𝑲, A K) :=
    fun w ι fs fc =>
      forall K : 𝑲,
        approx ι (fs K) (fc K).

  Global Instance ApproxMut {Γ1 Γ2 AT A} `{Approx AT A} : Approx (SMut Γ1 Γ2 AT) (CMut Γ1 Γ2 A).
  Proof.
    unfold SMut, CMut.
    eapply ApproxImpl.
  Defined.
  (* Defined. *)
  (*   (* fun w ι ms mc => *) *)
  (*   (*   forall POST δt ht δc hc, *) *)
  (*   (*     δc = inst δt ι -> *) *)
  (*   (*     hc = inst ht ι -> *) *)
  (*   (*     smut_wp ms POST δt ht ι -> *) *)
  (*   (*     cmut_wp mc POST δc hc. *) *)

  Global Instance ApproxTermVal {σ} : Approx (STerm σ) (Val σ) :=
    ApproxInst (AT := STerm σ).

  Global Instance ApproxStore {Δ : PCtx} :
    Approx (SStore Δ) (CStore Δ) :=
    ApproxInst.

  Global Instance ApproxNamedEnv {N : Set} {Δ : NCtx N Ty} :
    Approx (fun w => NamedEnv (Term w) Δ) (NamedEnv Val Δ) | 1 :=
    ApproxInst.

  (* Global Instance ApproxChunk : Approx Chunk SCChunk := *)
  (*   fun w ι t v => *)
  (*     v = inst t ι. *)

  (* Global Instance ApproxUnit : Approx Unit unit := *)
  (*   fun w ι t v => *)
  (*     v = inst t ι. *)

  Local Hint Unfold SMut : core.
  Local Hint Unfold CMut : core.

  Local Hint Unfold SMut : typeclass_instances.
  Local Hint Unfold CMut : typeclass_instances.

  Local Hint Unfold approx ApproxImpl ApproxBox ApproxInst ApproxPath (* ApproxMut  *)ApproxTermVal (* ApproxNamedEnv *) ApproxStore : core.

  Import ModalNotations.
  Open Scope modal.

  Lemma approx_four {AT A} `{Approx AT A} {w0 : World} (ι0 : Valuation w0) :
    forall (a0 : Box AT w0) (a : A),
      approx ι0 a0 a ->
      forall w1 (ω01 : w0 ⊒ w1) (ι1 : Valuation w1),
        ι0 = inst (sub_acc ω01) ι1 ->
        approx ι1 (four a0 ω01) a.
  Proof.
    unfold approx, ApproxBox.
    intros * H0 w1 ω01 ι1 ? w2 ω12 ι2 ? Hpc2.
    apply H0; auto.
    rewrite sub_acc_trans, inst_subst.
    now subst.
  Qed.
  Local Hint Resolve approx_four : core.

  Lemma approx_lift {AT A} `{InstLift AT A} {w0 : World} (ι0 : Valuation w0) (a : A) :
    approx ι0 (lift (T := AT) a) a.
  Proof.
    hnf. now rewrite inst_lift.
  Qed.
  Local Hint Resolve approx_lift : core.

  Ltac wsimpl :=
    repeat
      (try change (wctx (wsnoc ?w ?b)) with (wctx w ▻ b);
       (* try change (wsub (@wred_sup ?w ?b ?t)) with (sub_snoc (sub_id (wctx w)) b t); *)
       try change (wco (wsnoc ?w ?b)) with (subst (wco w) (sub_wk1 (b:=b)));
       try change (sub_acc (@acc_refl ?w)) with (sub_id (wctx w));
       (* try change (wsub (@wsnoc_sup ?w ?b)) with (@sub_wk1 (wctx w) b); *)
       try change (wctx (wformula ?w ?fml)) with (wctx w);
       try change (sub_acc (@acc_formula_right ?w ?fml)) with (sub_id (wctx w));
       try change (sub_acc (@acc_formulas_right ?w ?fmls)) with (sub_id (wctx w));
       try change (wco (wformula ?w ?fml)) with (cons fml (wco w));
       try change (wco (@wsubst ?w _ _ ?xIn ?t)) with (subst (wco w) (sub_single xIn t));
       try change (wctx (@wsubst ?w _ _ ?xIn ?t)) with (ctx.remove xIn);
       try change (sub_acc (@acc_subst_right ?w _ _ ?xIn ?t)) with (sub_single xIn t);
       rewrite <- ?sub_comp_wk1_tail, ?inst_subst, ?subst_sub_id,
         ?inst_sub_id, ?inst_sub_wk1, ?inst_sub_snoc,
         ?inst_lift, ?inst_sub_single_shift, ?inst_pathcondition_cons,
         ?sub_acc_trans, ?sub_acc_triangular, ?inst_triangular_right_inverse).
       (* repeat *)
       (*   match goal with *)
       (*   | |- approx _ (@smut_angelic _ _ _ _ _) (@cmut_angelic _ _ _) => *)
       (*     apply approx_angelic; auto *)
       (*   | |- approx _ (smut_pure _) (cmut_pure _) => *)
       (*     apply approx_pure; auto *)
       (*   | |- approx _ (smut_bind _ _) (cmut_bind _ _) => *)
       (*     apply approx_bind; auto *)
       (*   | |- forall (_ : World) (_ : Valuation _), instpc (wco _) _ -> _ => *)
       (*     let w := fresh "w" in *)
       (*     let ι := fresh "ι" in *)
       (*     let Hpc := fresh "Hpc" in *)
       (*     intros w ι Hpc *)
       (*   end). *)

  Module Path.

    Lemma approx_angelic_binary
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@angelic_binary w) (@or).
    Proof.
      intros PS1 PC1 HP1 PS2 PC2 HP2.
      intros [H1|H2]; [left|right]; auto.
    Qed.

    Lemma approx_demonic_binary
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@demonic_binary w) (@and).
    Proof.
      intros PS1 PC1 HP1 PS2 PC2 HP2.
      intros [H1 H2]; split; auto.
    Qed.

  End Path.

  Module Dijk.

    Lemma approx_pure {AT A} `{Approx AT A} {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SDijk.pure AT w) CDijk.pure.
    Proof.
      intros t v tv.
      intros POST__s POST__c HPOST.
      unfold SDijk.pure, CDijk.pure.
      apply HPOST; auto. cbn.
      now rewrite inst_sub_id.
    Qed.

    Lemma approx_bind {AT A BT B} `{Approx AT A, Approx BT B}
          {w0 : World} (ι0 : Valuation w0) (* (Hpc0 : instpc (wco w0) ι0) *) :
      approx ι0 (@SDijk.bind AT BT w0) (@CDijk.bind A B).
    Proof.
      (* cbv [approx ApproxBox ApproxImpl ApproxMut ApproxPath ApproxInst]. *)
      intros ms mc Hm fs fc Hf.
      intros POST__s POST__c HPOST.
      unfold SDijk.bind, CDijk.bind.
      apply Hm; eauto.
      intros w1 ω01 ι1 -> Hpc1.
      intros a1 a Ha.
      apply Hf; auto.
      eapply approx_four; eauto.
    Qed.

    Lemma approx_angelic (x : option 𝑺) (σ : Ty) :
      forall {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0),
        approx ι0 (@SDijk.angelic x σ w0) (@CDijk.angelic σ).
    Proof.
      intros w0 ι0 Hpc0.
      intros POST__s POST__c HPOST.
      intros [v Hwp]. exists v. revert Hwp.
      apply HPOST. cbn. now rewrite inst_sub_wk1.
      cbn. now rewrite inst_subst, inst_sub_wk1.
      reflexivity.
    Qed.

    Lemma approx_angelic_ctx {N : Set} {n : N -> 𝑺} {Δ : NCtx N Ty} :
      forall {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0),
        approx ι0 (@SDijk.angelic_ctx N n w0 Δ) (@CDijk.angelic_ctx N Δ).
    Proof.
      induction Δ; cbn [SDijk.angelic_ctx CDijk.angelic_ctx].
      - intros w0 ι0 Hpc0.
        now apply approx_pure.
      - destruct b as [x σ].
        intros w0 ι0 Hpc0.
        apply approx_bind; [|intros w1 ω01 ι1 -> Hpc1].
        apply approx_angelic; auto.
        intros t v ->.
        apply approx_bind; [|intros w2 ω12 ι2 -> Hpc2].
        apply IHΔ; auto.
        intros ts vs ->.
        apply approx_pure; auto.
        rewrite <- inst_persist.
        reflexivity.
    Qed.

    Lemma approx_demonic (x : option 𝑺) (σ : Ty) :
      forall {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0),
        approx ι0 (@SDijk.demonic x σ w0) (@CDijk.demonic σ).
    Proof.
      intros w0 ι0 Hpc0.
      intros POST__s POST__c HPOST.
      intros Hwp v.
      specialize (Hwp v).
      revert Hwp.
      eapply HPOST. cbn. now rewrite inst_sub_wk1.
      cbn. now rewrite inst_subst, inst_sub_wk1.
      reflexivity.
    Qed.

    Lemma approx_demonic_ctx {N : Set} {n : N -> 𝑺} {Δ : NCtx N Ty} :
      forall {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0),
        approx ι0 (@SDijk.demonic_ctx N n w0 Δ) (@CDijk.demonic_ctx N Δ).
    Proof.
      induction Δ.
      - intros w0 ι0 Hpc0.
        intros POST__s POST__c HPOST.
        unfold SDijk.demonic_ctx, CDijk.demonic_ctx, T.
        apply HPOST; wsimpl; try reflexivity; auto.
      - destruct b as [x σ].
        intros w0 ι0 Hpc0 POST__s POST__c HPOST; cbn.
        apply approx_demonic; auto.
        intros w1 ω01 ι1 -> Hpc1.
        intros t v tv.
        apply IHΔ; auto.
        intros w2 ω12 ι2 -> Hpc2.
        intros ts vs tvs.
        apply HPOST; cbn; wsimpl; auto.
        rewrite tv, tvs. hnf.
        rewrite <- inst_persist.
        reflexivity.
    Qed.

    Lemma approx_assume_formulas {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0)
      (fmls0 : List Formula w0) (P : Prop) (Heq : instpc fmls0 ι0 <-> P) :
      approx ι0 (@SDijk.assume_formulas w0 fmls0) (@CDijk.assume_formula P).
    Proof.
      intros POST__s POST__c HPOST. unfold SDijk.assume_formulas.
      intros Hwp Hfmls0. apply Heq in Hfmls0.
      destruct (solver_spec fmls0) as [[w1 [ζ fmls1]] Hsolver|Hsolver].
      - specialize (Hsolver ι0 Hpc0).
        destruct Hsolver as [Hν Hsolver]. inster Hν by auto.
        specialize (Hsolver (inst (sub_triangular_inv ζ) ι0)).
        rewrite inst_triangular_right_inverse in Hsolver; auto.
        inster Hsolver by now try apply entails_triangular_inv.
        destruct Hsolver as [Hsolver _]. inster Hsolver by auto.
        rewrite safe_assume_triangular, safe_assume_formulas_without_solver in Hwp.
        specialize (Hwp Hν Hsolver). revert Hwp.
        unfold four. apply HPOST; cbn; wsimpl; auto.
        rewrite inst_pathcondition_app. split; auto.
        now apply entails_triangular_inv.
      - intuition.
    Qed.

    Lemma approx_assume_formula {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0)
      (fml : Formula w0) (P : Prop) (Heq : inst fml ι0 <-> P) :
      approx ι0 (@SDijk.assume_formula w0 fml) (@CDijk.assume_formula P).
    Proof. unfold SDijk.assume_formula. apply approx_assume_formulas; cbn; intuition. Qed.

    Lemma approx_assert_formulas {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0)
      (msg : AMessage w0) (fmls0 : List Formula w0) (P : Prop) (Heq : instpc fmls0 ι0 <-> P) :
      approx ι0 (@SDijk.assert_formulas w0 msg fmls0) (@CDijk.assert_formula P).
    Proof.
      unfold SDijk.assert_formulas, CDijk.assert_formula.
      intros POST__s POST__c HPOST Hwp.
      destruct (solver_spec fmls0) as [[w1 [ζ fmls1]] Hsolver|Hsolver].
      - specialize (Hsolver ι0 Hpc0). destruct Hsolver as [_ Hsolver].
        rewrite safe_assert_triangular in Hwp. destruct Hwp as [Hν Hwp].
        rewrite safe_assert_formulas_without_solver in Hwp.
        destruct Hwp as [Hfmls Hwp].
        split.
        + apply Hsolver in Hfmls; rewrite ?inst_triangular_right_inverse; auto.
          now apply Heq.
          now apply entails_triangular_inv.
        + revert Hwp. unfold four.
          apply HPOST; cbn; wsimpl; eauto.
          rewrite inst_pathcondition_app. split; auto.
          now apply entails_triangular_inv.
      - intuition.
    Qed.

    Lemma approx_assert_formula {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0)
      (msg : AMessage w0) (fml : Formula w0) (P : Prop) (Heq : inst fml ι0 <-> P) :
      approx ι0 (@SDijk.assert_formula w0 msg fml) (@CDijk.assert_formula P).
    Proof. unfold SDijk.assert_formula. apply approx_assert_formulas; cbn; intuition. Qed.

    Lemma approx_angelic_list {M} `{Subst M, OccursCheck M} {AT A} `{Inst AT A}
      {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0) (msg : M w0) :
      approx ι0 (SDijk.angelic_list (A := AT) msg) (CDijk.angelic_list (A := A)).
    Proof.
      intros xs ? ->.
      induction xs; cbn - [inst];
        intros POST__s POST__c HPOST.
      - intros [].
      - cbn.
        apply Path.approx_angelic_binary; auto.
        apply HPOST; wsimpl; auto.
    Qed.

    Lemma approx_demonic_list {AT A} `{Inst AT A}
      {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0) :
      approx ι0 (@SDijk.demonic_list AT w0) (@CDijk.demonic_list A).
    Proof.
      intros xs ? ->.
      induction xs; cbn - [inst];
        intros POST__s POST__c HPOST.
      - constructor.
      - cbn.
        apply Path.approx_demonic_binary; auto.
        apply HPOST; wsimpl; auto.
    Qed.

    Lemma approx_angelic_finite {F} `{finite.Finite F}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) msg :
      approx (AT := SDijkstra (Const F)) ι (@SDijk.angelic_finite F _ _ w msg) (@CDijk.angelic_finite F _ _).
    Proof.
      unfold SDijk.angelic_finite, CDijk.angelic_finite.
      apply approx_angelic_list; auto.
      hnf. unfold inst, inst_const, inst_list.
      now rewrite List.map_id.
    Qed.

    Lemma approx_demonic_finite {F} `{finite.Finite F}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx (AT := SDijkstra (Const F)) ι (@SDijk.demonic_finite F _ _ w) (@CDijk.demonic_finite F _ _).
    Proof.
      unfold SDijk.demonic_finite, CDijk.demonic_finite.
      intros POST__s POST__c HPOST.
      apply approx_demonic_list; eauto.
      hnf. unfold inst, inst_const, inst_list.
      now rewrite List.map_id.
    Qed.

    (* Lemma approx_angelic_match_bool {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) *)
    (*   (msg : Message w) : *)
    (*   approx ι (@SDijk.angelic_match_bool w msg) (@CDijk.angelic_match_bool). *)
    (* Proof. *)
    (*   intros t v ->. *)
    (*   unfold SDijk.angelic_match_bool. *)
    (*   destruct (term_get_val_spec t). *)
    (*   - apply approx_pure; auto. *)
    (*   - unfold SDijk.angelic_match_bool'. *)
    (*     intros POST__s POST__c HPOST. *)
    (*     cbv [SDijk.angelic_binary SDijk.bind CDijk.pure SDijk.assert_formula]. *)
    (*     hnf. *)
    (*     intros δs δc Hδ hs hc Hh. *)
    (*     hnf. rewrite CMut.wp_angelic_match_bool. *)
    (*     destruct a. *)
    (*     + apply Hkt; wsimpl; eauto. *)
    (*     + apply Hkf; wsimpl; eauto. *)
    (*   - now apply approx_angelic_match_bool'. *)
    (* Qed. *)

  End Dijk.

  Section Basics.

    Lemma approx_dijkstra {Γ AT A} `{Approx AT A}
      {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0) :
      approx ι0 (@SMut.dijkstra Γ AT w0) (@CMut.dijkstra Γ A).
    Proof.
      intros ms mc Hm.
      intros POST__s POST__c HPOST.
      intros δs δc Hδ hs hc Hh.
      unfold SMut.dijkstra, CMut.dijkstra.
      apply Hm.
      intros w1 ω01 ι1 -> Hpc1.
      intros a1 a Ha.
      apply HPOST; auto.
      hnf. rewrite inst_persist. apply Hδ.
      hnf. rewrite inst_persist. apply Hh.
    Qed.
    Hint Resolve approx_dijkstra : core.

    Lemma approx_block {AT A} `{Approx AT A} {Γ1 Γ2} {w : World} (ι : Valuation w) :
      approx ι (@SMut.block Γ1 Γ2 AT w) CMut.block.
    Proof. unfold approx, ApproxMut, ApproxImpl. auto. Qed.

    Lemma approx_error {AT A D} `{Approx AT A} {Γ1 Γ2} {w : World} {ι: Valuation w} (func msg : string) (d : D) (cm : CMut Γ1 Γ2 A) :
      approx ι (@SMut.error Γ1 Γ2 AT D func msg d w) cm.
    Proof.
      intros POST__s POST__c HPOST.
      intros δs δc Hδ hs hc Hh [].
    Qed.
    Hint Resolve approx_error : core.

    Lemma approx_pure {AT A} `{Approx AT A} {Γ} {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.pure Γ AT w) CMut.pure.
    Proof.
      intros t v tv.
      intros POST__s POST__c HPOST.
      unfold SMut.pure, CMut.pure.
      apply HPOST; auto. cbn.
      now rewrite inst_sub_id.
    Qed.

    Lemma approx_bind {AT A BT B} `{Approx AT A, Approx BT B}
      {Γ1 Γ2 Γ3} {w0 : World} (ι0 : Valuation w0) (* (Hpc0 : instpc (wco w0) ι0) *) :
      approx ι0 (@SMut.bind Γ1 Γ2 Γ3 AT BT w0) (@CMut.bind Γ1 Γ2 Γ3 A B).
    Proof.
      (* cbv [approx ApproxBox ApproxImpl ApproxMut ApproxPath ApproxInst]. *)
      intros ms mc Hm fs fc Hf.
      intros POST__s POST__c HPOST.
      intros δs δc -> hs hc ->.
      unfold SMut.bind, CMut.bind.
      apply Hm; eauto.
      intros w1 ω01 ι1 -> Hpc1.
      intros a1 a Ha.
      apply Hf; auto.
      eapply approx_four; eauto.
    Qed.

    Lemma approx_bind_right {AT A BT B} `{Approx AT A, Approx BT B}
      {Γ1 Γ2 Γ3} {w0 : World} (ι0 : Valuation w0) (* (Hpc0 : instpc (wco w0) ι0) *) :
      approx ι0 (@SMut.bind_right Γ1 Γ2 Γ3 AT BT w0) (@CMut.bind_right Γ1 Γ2 Γ3 A B).
    Proof.
      intros ms1 mc1 Hm1 ms2 mc2 Hm2.
      intros POST__s POST__c HPOST.
      intros δs δc -> hs hc ->.
      unfold SMut.bind_right, CMut.bind_right, CMut.bind.
      apply Hm1; eauto.
      intros w1 ω01 ι1 -> Hpc1.
      intros a1 a Ha.
      apply Hm2; auto.
      eapply approx_four; eauto.
    Qed.

    Lemma approx_angelic (x : option 𝑺) (σ : Ty)
      {Γ : PCtx} {w0 : World} (ι0 : Valuation w0)
      (Hpc0 : instpc (wco w0) ι0) :
      approx ι0 (@SMut.angelic Γ x σ w0) (@CMut.angelic Γ σ).
    Proof.
      intros POST__s POST__c HPOST.
      intros δs δc -> hs hc ->.
      intros [v Hwp]; exists v; revert Hwp.
      apply HPOST. cbn. now rewrite inst_sub_wk1.
      cbn. now rewrite inst_subst, inst_sub_wk1.
      reflexivity.
      hnf. cbn. now rewrite inst_subst, ?inst_sub_wk1.
      hnf. cbn. now rewrite inst_subst, ?inst_sub_wk1.
    Qed.
    Hint Resolve approx_angelic : core.

    Lemma approx_demonic (x : option 𝑺) (σ : Ty)
      {Γ : PCtx} {w0 : World} (ι0 : Valuation w0)
      (Hpc0 : instpc (wco w0) ι0) :
      approx ι0 (@SMut.demonic Γ x σ w0) (@CMut.demonic Γ σ).
    Proof.
      intros POST__s POST__c HPOST.
      intros δs δc -> hs hc ->.
      intros Hwp v. cbn in Hwp. specialize (Hwp v). revert Hwp.
      apply HPOST. cbn. now rewrite inst_sub_wk1.
      cbn. now rewrite inst_subst, inst_sub_wk1.
      reflexivity.
      hnf. cbn. now rewrite inst_subst, ?inst_sub_wk1.
      hnf. cbn. now rewrite inst_subst, ?inst_sub_wk1.
    Qed.
    Hint Resolve approx_demonic : core.

    Lemma approx_angelic_ctx {N : Set} (n : N -> 𝑺) {Γ : PCtx} (Δ : NCtx N Ty) :
      forall {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0),
        approx ι0 (@SMut.angelic_ctx N n Γ w0 Δ) (@CMut.angelic_ctx N Γ Δ).
    Proof.
      intros w0 ι0 Hpc0. unfold SMut.angelic_ctx, CMut.angelic_ctx.
      apply approx_dijkstra; auto.
      now apply Dijk.approx_angelic_ctx.
    Qed.

    Lemma approx_demonic_ctx {N : Set} (n : N -> 𝑺) {Γ : PCtx} (Δ : NCtx N Ty) :
      forall {w0 : World} (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0),
        approx ι0 (@SMut.demonic_ctx N n Γ w0 Δ) (@CMut.demonic_ctx N Γ Δ).
    Proof.
      intros w0 ι0 Hpc0. unfold SMut.demonic_ctx, CMut.demonic_ctx.
      apply approx_dijkstra; auto.
      now apply Dijk.approx_demonic_ctx.
    Qed.

    Lemma approx_debug {AT A D} `{Approx AT A, Subst D, SubstLaws D, OccursCheck D} {Γ1 Γ2} {w0 : World} (ι0 : Valuation w0)
          (Hpc : instpc (wco w0) ι0) f ms mc :
      approx ι0 ms mc ->
      approx ι0 (@SMut.debug AT D _ _ _ _ Γ1 Γ2 w0 f ms) mc.
    Proof.
      intros Hap.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 -> hs0 hc0 ->.
      unfold SMut.debug. hnf.
      cbn. intros [HP]. revert HP.
      apply Hap; auto.
    Qed.

    Lemma approx_angelic_binary {AT A} `{Approx AT A} {Γ1 Γ2} {w : World} (ι : Valuation w) :
      approx ι (@SMut.angelic_binary Γ1 Γ2 AT w) (@CMut.angelic_binary Γ1 Γ2 A).
    Proof.
      intros ms1 mc1 Hm1 ms2 mc2 Hm2.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 -> hs0 hc0 ->.
      unfold SMut.angelic_binary, CMut.angelic_binary.
      intros [HYP|HYP]; [left|right]; revert HYP.
      - apply Hm1; auto.
      - apply Hm2; auto.
    Qed.

    Lemma approx_demonic_binary {AT A} `{Approx AT A} {Γ1 Γ2} {w : World} (ι : Valuation w) :
      approx ι (@SMut.demonic_binary Γ1 Γ2 AT w) (@CMut.demonic_binary Γ1 Γ2 A).
    Proof.
      intros ms1 mc1 Hm1 ms2 mc2 Hm2.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 -> hs0 hc0 ->.
      unfold SMut.demonic_binary, CMut.demonic_binary.
      intros [H1 H2]. split.
      - revert H1. apply Hm1; auto.
      - revert H2. apply Hm2; auto.
    Qed.

    Lemma approx_angelic_list {M} {subM : Subst M} {occM : OccursCheck M} {AT A} `{Inst AT A} {Γ}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι)
      (msg : SStore Γ w -> SHeap w -> M w) :
      approx ι (SMut.angelic_list (A := AT) msg) (@CMut.angelic_list A Γ).
    Proof.
      intros ls lc Hl.
      unfold SMut.angelic_list, CMut.angelic_list.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 Hδ0 hs0 hc0 Hh0.
      apply approx_dijkstra; eauto.
      apply Dijk.approx_angelic_list; auto.
    Qed.

    Lemma approx_angelic_finite {F} `{finite.Finite F} {Γ}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) msg :
      approx (AT := SMut Γ Γ (Const F)) ι (@SMut.angelic_finite Γ F _ _ w msg) (@CMut.angelic_finite Γ F _ _).
    Proof.
      unfold SMut.angelic_finite, CMut.angelic_finite.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 Hδ0 hs0 hc0 Hh0.
      eapply approx_dijkstra; eauto.
      apply Dijk.approx_angelic_finite; auto.
    Qed.

    Lemma approx_demonic_finite {F} `{finite.Finite F} {Γ}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx (AT := SMut Γ Γ (Const F)) ι (@SMut.demonic_finite Γ F _ _ w) (@CMut.demonic_finite Γ F _ _).
    Proof.
      unfold SMut.demonic_finite, CMut.demonic_finite.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 Hδ0 hs0 hc0 Hh0.
      eapply approx_dijkstra; eauto.
      apply Dijk.approx_demonic_finite; auto.
    Qed.

  End Basics.

  Section AssumeAssert.

    Lemma approx_assume_formula {Γ} {w0 : World} {ι0 : Valuation w0} (Hpc0 : instpc (wco w0) ι0)
      (fml__s : Formula w0) (fml__c : Prop) (Hfml : fml__c <-> inst fml__s ι0) :
      approx ι0 (@SMut.assume_formula Γ w0 fml__s) (CMut.assume_formula fml__c).
    Proof.
      unfold SMut.assume_formula, CMut.assume_formula.
      apply approx_dijkstra; auto.
      now apply Dijk.approx_assume_formula.
    Qed.

    Lemma approx_box_assume_formula {Γ} {w0 : World} {ι0 : Valuation w0} (Hpc0 : instpc (wco w0) ι0)
      (fml__s : Formula w0) (fml__c : Prop) (Hfml : fml__c <-> inst fml__s ι0) :
      approx ι0 (@SMut.box_assume_formula Γ w0 fml__s) (CMut.assume_formula fml__c).
    Proof.
      unfold SMut.box_assume_formula, fmap_box.
      intros w1 ω01 ι1 -> Hpc1.
      apply approx_assume_formula; auto.
      now rewrite inst_persist.
    Qed.

    Lemma approx_assert_formula {Γ} {w0 : World} (ι0 : Valuation w0) (Hpc : instpc (wco w0) ι0)
      (fml__s : Formula w0) (fml__c : Prop) (Hfml : fml__c <-> inst fml__s ι0) :
      approx ι0 (@SMut.assert_formula Γ w0 fml__s) (@CMut.assert_formula Γ fml__c).
    Proof.
      unfold SMut.assert_formula, CMut.assert_formula.
      intros POST__s POST__c HPOST.
      intros δs δc Hδ hs hc Hh.
      apply approx_dijkstra; auto.
      now apply Dijk.approx_assert_formula.
    Qed.

    Lemma approx_box_assert_formula {Γ} {w0 : World} {ι0 : Valuation w0} (Hpc0 : instpc (wco w0) ι0)
      (fml__s : Formula w0) (fml__c : Prop) (Hfml : fml__c <-> inst fml__s ι0) :
      approx ι0 (@SMut.box_assert_formula Γ w0 fml__s) (CMut.assert_formula fml__c).
    Proof.
      unfold SMut.box_assert_formula, fmap_box.
      intros w1 ω01 ι1 -> Hpc1.
      apply approx_assert_formula; auto.
      now rewrite inst_persist.
    Qed.

    Lemma approx_assert_formulas {Γ} {w0 : World} (ι0 : Valuation w0) (Hpc : instpc (wco w0) ι0)
      (fmls__s : List Formula w0) (fmls__c : Prop) (Hfmls : fmls__c <-> instpc fmls__s ι0) :
      approx ι0 (@SMut.assert_formulas Γ w0 fmls__s) (@CMut.assert_formula Γ fmls__c).
    Proof.
      intros POST__s POST__c HPOST.
      intros δs δc -> hs hc ->.
      unfold SMut.assert_formulas, CMut.assert_formula.
      apply approx_dijkstra; auto.
      now apply Dijk.approx_assert_formulas.
    Qed.

  End AssumeAssert.

  Section PatternMatching.

    Lemma approx_angelic_match_bool' {AT A} `{Approx AT A} {Γ1 Γ2}
      {w : World} (ι : Valuation w) (Hpc: instpc (wco w) ι) :
      approx ι (@SMut.angelic_match_bool' AT Γ1 Γ2 w) (CMut.angelic_match_bool (A := A)).
    Proof.
      unfold SMut.angelic_match_bool', CMut.angelic_match_bool.
      intros t v ->.
      intros kt__s kt__c Hkt.
      intros kf__s kf__c Hkf.
      apply approx_angelic_binary; eauto.
      apply approx_bind_right; eauto.
      apply approx_assert_formula; eauto.
      apply approx_bind_right; eauto.
      apply approx_assert_formula; eauto.
      cbn. unfold is_true. now rewrite negb_true_iff.
    Qed.

    Lemma approx_angelic_match_bool {AT A} `{Approx AT A} {Γ1 Γ2}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.angelic_match_bool AT Γ1 Γ2 w) (CMut.angelic_match_bool (A := A)).
    Proof.
      unfold SMut.angelic_match_bool.
      intros t v ->.
      destruct (term_get_val_spec t).
      - rewrite H0.
        intros kt__s kt__c Hkt.
        intros kf__s kf__c Hkf.
        intros POST__s POST__c HPOST.
        intros δs δc Hδ hs hc Hh.
        hnf. rewrite CMut.wp_angelic_match_bool.
        destruct a.
        + apply Hkt; wsimpl; eauto.
        + apply Hkf; wsimpl; eauto.
      - now apply approx_angelic_match_bool'.
    Qed.

    Lemma approx_box_angelic_match_bool {AT A} `{Approx AT A} {Γ1 Γ2}
      {w : World} (ι : Valuation w) :
      approx ι (@SMut.box_angelic_match_bool AT Γ1 Γ2 w) (CMut.angelic_match_bool (A := A)).
    Proof.
      unfold SMut.box_angelic_match_bool, fmap_box, K.
      intros t v ->.
      intros kt__s kt__c Hkt.
      intros kf__s kf__c Hkf.
      intros w1 ω01 ι1 -> Hpc1.
      apply approx_angelic_match_bool; wsimpl; eauto.
      rewrite <- inst_persist; auto.
    Qed.

    Lemma approx_demonic_match_bool' {AT A} `{Approx AT A} {Γ1 Γ2}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_bool' AT Γ1 Γ2 w) (CMut.demonic_match_bool (A := A)).
    Proof.
      unfold SMut.demonic_match_bool, CMut.demonic_match_bool.
      intros t v ->.
      intros kt__s kt__c Hkt.
      intros kf__s kf__c Hkf.
      apply approx_demonic_binary; eauto.
      apply approx_bind_right; eauto.
      apply approx_assume_formula; eauto.
      apply approx_bind_right; eauto.
      apply approx_assume_formula; eauto.
      cbn. unfold is_true. now rewrite negb_true_iff.
    Qed.

    Lemma approx_demonic_match_bool {AT A} `{Approx AT A} {Γ1 Γ2} {w : World}
      (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_bool AT Γ1 Γ2 w) (CMut.demonic_match_bool (A := A)).
    Proof.
      unfold SMut.demonic_match_bool.
      intros t v ->.
      destruct (term_get_val_spec t).
      - rewrite H0.
        intros kt__s kt__c Hkt.
        intros kf__s kf__c Hkf.
        intros POST__s POST__c HPOST.
        intros δs δc Hδ hs hc Hh.
        hnf. rewrite CMut.wp_demonic_match_bool.
        destruct a.
        + apply Hkt; wsimpl; eauto.
        + apply Hkf; wsimpl; eauto.
      - now apply approx_demonic_match_bool'.
    Qed.

    Lemma approx_box_demonic_match_bool {AT A} `{Approx AT A} {Γ1 Γ2}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.box_demonic_match_bool AT Γ1 Γ2 w) (CMut.demonic_match_bool (A := A)).
    Proof.
      unfold SMut.box_demonic_match_bool, fmap_box, K.
      intros t v ->.
      intros kt__s kt__c Hkt.
      intros kf__s kf__c Hkf.
      intros w1 ω01 ι1 -> Hpc1.
      apply approx_demonic_match_bool; wsimpl; eauto.
      rewrite <- inst_persist. auto.
    Qed.

    Lemma approx_angelic_match_enum {AT A} `{Approx AT A} {E : enumi} {Γ1 Γ2 : PCtx}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.angelic_match_enum AT E Γ1 Γ2 w) (@CMut.angelic_match_enum A E Γ1 Γ2).
    Proof.
      intros t v ->.
      intros ks kc Hk.
      unfold SMut.angelic_match_enum, CMut.angelic_match_enum.
      apply approx_bind.
      apply approx_angelic_finite; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros EK1 EK2 ->.
      apply approx_bind_right.
      apply approx_assert_formula; cbn; wsimpl; auto.
      now rewrite <- inst_persist.
      intros w2 ω12 ι2 -> Hpc2.
      eapply Hk; wsimpl; auto.
    Qed.

    Lemma approx_demonic_match_enum {AT A} `{Approx AT A} {E : enumi} {Γ1 Γ2 : PCtx}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_enum AT E Γ1 Γ2 w) (@CMut.demonic_match_enum A E Γ1 Γ2).
    Proof.
      intros t v ->.
      intros ks kc Hk.
      unfold SMut.demonic_match_enum, CMut.demonic_match_enum.
      apply approx_bind.
      apply approx_demonic_finite; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros EK1 EK2 ->.
      apply approx_bind_right.
      apply approx_assume_formula; cbn; wsimpl; auto.
      now rewrite <- inst_persist.
      intros w2 ω12 ι2 -> Hpc2.
      eapply Hk; wsimpl; auto.
    Qed.

    Lemma approx_angelic_match_sum {AT A} `{Approx AT A} {Γ1 Γ2} x y σ τ
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.angelic_match_sum AT Γ1 Γ2 x y σ τ w) (@CMut.angelic_match_sum A Γ1 Γ2 σ τ).
    Proof.
      intros t v ->.
      intros kl kl__c Hk__l.
      intros kr kr__c Hk__r.
      unfold SMut.angelic_match_sum, CMut.angelic_match_sum.
      eapply approx_angelic_binary, approx_bind.
      - eapply approx_bind; try (eapply approx_angelic; assumption).
        intros w1 r01 ι1 -> Hpc1.
        intros v1 vc1 ->.
        eapply approx_bind_right.
        * eapply approx_assert_formula; try assumption. cbn.
          now rewrite <- inst_persist.
        * intros w2 r12 ι2 -> Hpc2.
          eapply (approx_four Hk__l); eauto.
          now rewrite <- inst_persist.
      - now eapply approx_angelic.
      - intros w1 r01 ι1 -> Hpc1.
        intros v1 vc1 ->.
        eapply approx_bind_right.
        + eapply approx_assert_formula; try assumption.
          now rewrite <- inst_persist.
        + intros w2 r12 ι2 -> Hpc2.
          eapply (approx_four Hk__r); eauto.
          now rewrite <- inst_persist.
    Qed.

    Lemma approx_demonic_match_sum {AT A} `{Approx AT A} {Γ1 Γ2} x y σ τ
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_sum AT Γ1 Γ2 x y σ τ w) (@CMut.demonic_match_sum A Γ1 Γ2 σ τ).
    Proof.
      intros t v ->.
      intros kl kl__c Hk__l.
      intros kr kr__c Hk__r.
      unfold SMut.demonic_match_sum, CMut.demonic_match_sum.
      eapply approx_demonic_binary, approx_bind.
      - eapply approx_bind; try (eapply approx_demonic; assumption).
        intros w1 r01 ι1 -> Hpc1.
        intros v1 vc1 ->.
        eapply approx_bind_right.
        * eapply approx_assume_formula; try assumption.
          now rewrite <- inst_persist.
        * intros w2 r12 ι2 -> Hpc2.
          eapply (approx_four Hk__l); eauto.
          now rewrite <- inst_persist.
      - now eapply approx_demonic.
      - intros w1 r01 ι1 -> Hpc1.
        intros v1 vc1 ->.
        eapply approx_bind_right.
        + eapply approx_assume_formula; try assumption.
          now rewrite <- inst_persist.
        + intros w2 r12 ι2 -> Hpc2.
          eapply (approx_four Hk__r); eauto.
          now rewrite <- inst_persist.
    Qed.

    Lemma approx_angelic_match_prod {AT A} `{Approx AT A} {Γ1 Γ2} x y σ τ
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.angelic_match_prod AT Γ1 Γ2 x y σ τ w) (@CMut.angelic_match_prod A Γ1 Γ2 σ τ).
    Proof.
      intros t v ->.
      intros k k__c Hk.
      unfold SMut.angelic_match_prod, CMut.angelic_match_prod.
      eapply approx_bind; try (eapply approx_angelic; assumption).
      intros w1 r01 ι1 -> Hpc1.
      intros v1 vc1 ->.
      eapply approx_bind; try (eapply approx_angelic; assumption).
      intros w2 r12 ι2 -> Hpc2.
      intros v2 vc2 ->.
      eapply approx_bind_right.
      - eapply approx_assert_formula; try assumption. cbn - [Val].
        change (inst_term ?t ?ι) with (inst t ι).
        rewrite (inst_persist (AT := STerm _) (A := Val _)).
        rewrite (inst_persist (AT := STerm _) (A := Val _)).
        now rewrite sub_acc_trans, inst_subst.
      - intros w3 r23 ι3 -> Hpc3.
        eapply (approx_four Hk); eauto.
        + now rewrite sub_acc_trans, inst_subst.
        + rewrite <- ?inst_subst, <- subst_sub_comp.
          now rewrite <- sub_acc_trans, inst_subst, <- inst_persist.
        + now rewrite <- inst_persist.
    Qed.

    Lemma approx_demonic_match_prod {AT A} `{Approx AT A} {Γ1 Γ2} x y σ τ
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_prod AT Γ1 Γ2 x y σ τ w) (@CMut.demonic_match_prod A Γ1 Γ2 σ τ).
    Proof.
      intros t v ->.
      intros k k__c Hk.
      unfold SMut.demonic_match_prod, CMut.demonic_match_prod.
      apply approx_bind; try (eapply approx_demonic; assumption).
      intros w1 r01 ι1 -> Hpc1.
      intros v1 vc1 ->.
      apply approx_bind; try (eapply approx_demonic; assumption).
      intros w2 r12 ι2 -> Hpc2.
      intros v2 vc2 ->.
      apply approx_bind_right.
      - apply approx_assume_formula; try assumption. cbn - [Val].
        change (inst_term ?t ?ι) with (inst t ι).
        rewrite (inst_persist (AT := STerm _) (A := Val _)).
        rewrite (inst_persist (AT := STerm _) (A := Val _)).
        now rewrite sub_acc_trans, inst_subst.
      - intros w3 r23 ι3 -> Hpc3.
        eapply (approx_four Hk); eauto.
        + now rewrite sub_acc_trans, inst_subst.
        + rewrite <- ?inst_subst, <- subst_sub_comp.
          now rewrite <- sub_acc_trans, inst_subst, <- inst_persist.
        + now rewrite <- inst_persist.
    Qed.

    Lemma approx_angelic_match_list {AT A} `{Approx AT A} {Γ1 Γ2} xhead xtail σ
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.angelic_match_list AT Γ1 Γ2 xhead xtail σ w) (@CMut.angelic_match_list A Γ1 Γ2 σ).
    Proof.
      intros t ? ->.
      intros sknil cknil Hknil.
      intros skcons ckcons Hkcons.
      unfold SMut.angelic_match_list, CMut.angelic_match_list.
      apply approx_angelic_binary.
      - apply approx_bind_right; auto.
        apply approx_assert_formula; auto.
      - apply approx_bind; auto.
        apply approx_angelic; auto.
        intros w1 ω01 ι1 -> Hpc1.
        intros thead vhead ->.
        apply approx_bind; auto.
        apply approx_angelic; auto.
        intros w2 ω12 ι2 -> Hpc2.
        intros ttail vtail ->.
        apply approx_bind_right; auto.
        + apply approx_assert_formula; auto.
          cbn - [Val].
          change (inst_term ?t ?ι) with (inst t ι).
          rewrite (inst_persist (AT := STerm _) (A := Val _)).
          rewrite (inst_persist (AT := STerm _) (A := Val _)).
          now rewrite sub_acc_trans, inst_subst.
        + intros w3 ω23 ι3 -> Hpc3.
          apply Hkcons; wsimpl; eauto.
          rewrite <- ?inst_subst, <- subst_sub_comp.
          now rewrite <- sub_acc_trans, inst_subst, <- inst_persist.
          now rewrite <- inst_persist.
    Qed.

    Lemma approx_demonic_match_list {AT A} `{Approx AT A} {Γ1 Γ2} xhead xtail σ
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_list AT Γ1 Γ2 xhead xtail σ w) (@CMut.demonic_match_list A Γ1 Γ2 σ).
    Proof.
      intros t ? ->.
      intros sknil cknil Hknil.
      intros skcons ckcons Hkcons.
      unfold SMut.demonic_match_list, CMut.demonic_match_list.
      apply approx_demonic_binary.
      - apply approx_bind_right; auto.
        apply approx_assume_formula; auto.
      - apply approx_bind; auto.
        apply approx_demonic; auto.
        intros w1 ω01 ι1 -> Hpc1.
        intros thead vhead ->.
        apply approx_bind; auto.
        apply approx_demonic; auto.
        intros w2 ω12 ι2 -> Hpc2.
        intros ttail vtail ->.
        apply approx_bind_right; auto.
        + apply approx_assume_formula; auto.
          cbn - [Val].
          change (inst_term ?t ?ι) with (inst t ι).
          rewrite (inst_persist (AT := STerm _) (A := Val _)).
          rewrite (inst_persist (AT := STerm _) (A := Val _)).
          now rewrite sub_acc_trans, inst_subst.
        + intros w3 ω23 ι3 -> Hpc3.
          apply Hkcons; wsimpl; eauto.
          rewrite <- ?inst_subst, <- subst_sub_comp.
          now rewrite <- sub_acc_trans, inst_subst, <- inst_persist.
          now rewrite <- inst_persist.
    Qed.

    Lemma approx_angelic_match_record' {N : Set} (n : N -> 𝑺) {R AT A} `{Approx AT A} {Γ1 Γ2}
      {Δ : NCtx N Ty} {p : RecordPat (recordf_ty R) Δ}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.angelic_match_record' N n AT R Γ1 Γ2 Δ p w) (@CMut.angelic_match_record N A R Γ1 Γ2 Δ p).
    Proof.
      intros t v ->.
      intros k k__c Hk.
      unfold SMut.angelic_match_record', CMut.angelic_match_record.
      eapply approx_bind; try (eapply approx_angelic_ctx; assumption).
      intros w1 r01 ι1 -> Hpc1.
      intros v1 vc1 ->.
      apply approx_bind_right.
      - apply approx_assert_formula; try assumption. cbn - [Val].
        now rewrite <- inst_persist, (inst_record_pattern_match_reverse ι1 p).
      - intros w2 r12 ι2 -> Hpc2.
        eapply (approx_four Hk); eauto.
        now rewrite <- inst_persist.
    Qed.

    Lemma approx_angelic_match_record {N : Set} (n : N -> 𝑺) {R AT A} `{Approx AT A} {Γ1 Γ2}
      {Δ : NCtx N Ty} {p : RecordPat (recordf_ty R) Δ}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.angelic_match_record N n AT R Γ1 Γ2 Δ p w) (@CMut.angelic_match_record N A R Γ1 Γ2 Δ p).
    Proof.
      intros t v ->.
      intros c c__c Hc.
      unfold SMut.angelic_match_record.
      destruct (term_get_record_spec t).
      - intros P2 Pc2 HP2.
        intros c2 cc2 Hc2.
        intros s2 sc2 Hs2.
        hnf.
        rewrite CMut.wp_angelic_match_record.
        apply Hc; wsimpl; eauto.
        hnf.
        unfold record_pattern_match_val.
        rewrite H0. rewrite recordv_unfold_fold.
        symmetry.
        apply inst_record_pattern_match.
      - apply approx_angelic_match_record'; auto.
    Qed.

    Lemma approx_demonic_match_record' {N : Set} (n : N -> 𝑺) {R AT A} `{Approx AT A} {Γ1 Γ2}
      {Δ : NCtx N Ty} {p : RecordPat (recordf_ty R) Δ}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_record' N n AT R Γ1 Γ2 Δ p w) (@CMut.demonic_match_record N A R Γ1 Γ2 Δ p).
    Proof.
      intros t v ->.
      intros k k__c Hk.
      unfold SMut.demonic_match_record', CMut.demonic_match_record.
      eapply approx_bind. try (eapply approx_demonic_ctx; assumption).
      intros w1 r01 ι1 -> Hpc1.
      intros v1 vc1 ->.
      eapply approx_bind_right.
      - eapply approx_assume_formula; try assumption. cbn - [Val].
        now rewrite <- inst_persist, (inst_record_pattern_match_reverse ι1 p).
      - intros w2 r12 ι2 -> Hpc2.
        eapply (approx_four Hk); eauto.
        now rewrite <- inst_persist.
    Qed.

    Lemma approx_demonic_match_record {N : Set} (n : N -> 𝑺) {R AT A} `{Approx AT A} {Γ1 Γ2}
      {Δ : NCtx N Ty} {p : RecordPat (recordf_ty R) Δ}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_record N n AT R Γ1 Γ2 Δ p w) (@CMut.demonic_match_record N A R Γ1 Γ2 Δ p).
    Proof.
      intros t v ->.
      intros c c__c Hc.
      unfold SMut.demonic_match_record.
      destruct (term_get_record_spec t).
      - intros P2 Pc2 HP2.
        intros c2 cc2 Hc2.
        intros s2 sc2 Hs2.
        hnf.
        rewrite CMut.wp_demonic_match_record.
        apply Hc; wsimpl; eauto.
        hnf.
        unfold record_pattern_match_val.
        rewrite H0. rewrite recordv_unfold_fold.
        change (fun Σ => @Env (N ∷ Ty) (fun τ => Term Σ (type τ)) Δ) with (fun Σ => @NamedEnv N Ty (Term Σ) Δ).
        now rewrite inst_record_pattern_match.
      - apply approx_demonic_match_record'; auto.
    Qed.

    Lemma approx_angelic_match_tuple {N : Set} (n : N -> 𝑺) {σs AT A} `{Approx AT A} {Γ1 Γ2}
      {Δ : NCtx N Ty} {p : TuplePat σs Δ}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.angelic_match_tuple N n AT σs Γ1 Γ2 Δ p w) (@CMut.angelic_match_tuple N A σs Γ1 Γ2 Δ p).
    Proof.
      intros t v ->.
      intros k k__c Hk.
      unfold SMut.angelic_match_tuple, CMut.angelic_match_tuple.
      apply approx_bind; try (apply approx_angelic_ctx; assumption).
      intros w1 r01 ι1 -> Hpc1.
      intros v1 vc1 ->.
      change (fun Σ => @Env (N ∷ Ty) (fun τ => Term Σ (type τ)) Δ) with (fun Σ => @NamedEnv N Ty (Term Σ) Δ).
      apply approx_bind_right.
      - apply approx_assert_formula; try assumption. cbn - [Val].
        rewrite inst_term_tuple.
        rewrite inst_tuple_pattern_match_reverse.
        rewrite <- inst_persist.
        unfold tuple_pattern_match_val.
        split; intros <-.
        + now rewrite tuple_pattern_match_env_inverse_left, envrec.of_to_env.
        + now rewrite envrec.to_of_env, tuple_pattern_match_env_inverse_right.
      - intros w2 r12 ι2 -> Hpc2.
        eapply (approx_four Hk); eauto.
        now rewrite <- inst_persist.
    Qed.

    Lemma approx_demonic_match_tuple {N : Set} (n : N -> 𝑺) {σs AT A} `{Approx AT A} {Γ1 Γ2}
      {Δ : NCtx N Ty} {p : TuplePat σs Δ}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_tuple N n AT σs Γ1 Γ2 Δ p w) (@CMut.demonic_match_tuple N A σs Γ1 Γ2 Δ p).
    Proof.
      intros t v ->.
      intros k k__c Hk.
      unfold SMut.demonic_match_tuple, CMut.demonic_match_tuple.
      apply approx_bind; try (apply approx_demonic_ctx; assumption).
      intros w1 r01 ι1 -> Hpc1.
      intros v1 vc1 ->.
      change (fun Σ => @Env (N ∷ Ty) (fun τ => Term Σ (type τ)) Δ) with (fun Σ => @NamedEnv N Ty (Term Σ) Δ).
      apply approx_bind_right.
      - apply approx_assume_formula; try assumption. cbn - [Val].
        rewrite inst_term_tuple.
        rewrite inst_tuple_pattern_match_reverse.
        rewrite <- inst_persist.
        unfold tuple_pattern_match_val.
        split; intros <-.
        + now rewrite tuple_pattern_match_env_inverse_left, envrec.of_to_env.
        + now rewrite envrec.to_of_env, tuple_pattern_match_env_inverse_right.
      - intros w2 r12 ι2 -> Hpc2.
        eapply (approx_four Hk); eauto.
        now rewrite <- inst_persist.
    Qed.

    Lemma approx_angelic_match_pattern {N : Set} (n : N -> 𝑺) {σ} {Δ : NCtx N Ty}
          {p : Pattern Δ σ} {Γ}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) {msg} :
      approx ι (@SMut.angelic_match_pattern N n σ Δ p Γ w msg) (@CMut.angelic_match_pattern N σ Δ p Γ).
    Proof.
      intros t v ->.
      intros k k__c Hk.
      unfold SMut.angelic_match_pattern, CMut.angelic_match_pattern.
      eapply approx_bind; try (eapply approx_angelic_ctx; assumption); try assumption.
      intros w1 r01 ι1 -> Hpc1.
      intros ts vs ->.
      change (fun Σ => @Env (N ∷ Ty) (fun τ => Term Σ (type τ)) Δ) with (fun Σ => @NamedEnv N Ty (Term Σ) Δ).
      eapply approx_bind_right.
      - eapply approx_assert_formula; try assumption. cbn - [Val].
        rewrite inst_pattern_match_env_reverse.
        rewrite <- inst_persist.
        split; intros <-.
        + now rewrite pattern_match_val_inverse_left.
        + now rewrite pattern_match_val_inverse_right.
      - intros w2 r12 ι2 -> Hpc2.
        eapply approx_pure; try assumption.
        now rewrite <- inst_persist.
    Qed.

    Lemma approx_angelic_match_union {N : Set} (n : N -> 𝑺) {AT A} `{Approx AT A} {Γ1 Γ2 : PCtx} {U : unioni}
      {Δ : unionk U -> NCtx N Ty} {p : forall K : unionk U, Pattern (Δ K) (unionk_ty U K)}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.angelic_match_union N n AT Γ1 Γ2 U Δ p w) (@CMut.angelic_match_union N A Γ1 Γ2 U Δ p).
    Proof.
      intros t v ->.
      intros k k__c Hk.
      unfold SMut.angelic_match_union, CMut.angelic_match_union.
      apply approx_bind; try (apply approx_angelic_finite; assumption).
      intros w1 r01 ι1 -> Hpc1.
      intros v1 vc1 ->.
      apply approx_bind; try (apply approx_angelic; assumption).
      intros w2 r12 ι2 -> Hpc2.
      intros v2 vc2 ->.
      eapply approx_bind_right.
      - eapply approx_assert_formula; try assumption. cbn - [Val].
        change (inst v1 _) with v1.
        change (inst_term ?t ?ι) with (inst t ι).
        rewrite (inst_persist (AT := STerm _) (A := Val _)).
        now rewrite sub_acc_trans, inst_subst.
      - intros w3 r23 ι3 -> Hpc3.
        eapply approx_bind.
        + eapply approx_angelic_match_pattern; try assumption.
          now rewrite <- inst_persist.
        + change (inst v1 _) with v1.
          specialize (Hk v1).
          eapply (approx_four Hk).
          now rewrite ?sub_acc_trans, ?inst_subst.
    Qed.

    Lemma approx_demonic_match_pattern {N : Set} (n : N -> 𝑺) {σ} {Δ : NCtx N Ty}
          {p : Pattern Δ σ} {Γ}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_pattern N n σ Δ p Γ w) (@CMut.demonic_match_pattern N σ Δ p Γ).
    Proof.
      intros t v ->.
      intros k k__c Hk.
      unfold SMut.demonic_match_pattern, CMut.demonic_match_pattern.
      eapply approx_bind; try (eapply approx_demonic_ctx; assumption); try assumption.
      intros w1 r01 ι1 -> Hpc1.
      intros ts vs ->.
      change (fun Σ => @Env (N ∷ Ty) (fun τ => Term Σ (type τ)) Δ) with (fun Σ => @NamedEnv N Ty (Term Σ) Δ).
      eapply approx_bind_right.
      - eapply approx_assume_formula; try assumption. cbn - [Val].
        rewrite inst_pattern_match_env_reverse.
        rewrite <- inst_persist.
        split; intros <-.
        + now rewrite pattern_match_val_inverse_left.
        + now rewrite pattern_match_val_inverse_right.
      - intros w2 r12 ι2 -> Hpc2.
        eapply approx_pure; try assumption.
        now rewrite <- inst_persist.
    Qed.

    Lemma approx_demonic_match_union {N : Set} (n : N -> 𝑺) {AT A} `{Approx AT A} {Γ1 Γ2 : PCtx} {U : unioni}
      {Δ : unionk U -> NCtx N Ty} {p : forall K : unionk U, Pattern (Δ K) (unionk_ty U K)}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_union N n AT Γ1 Γ2 U Δ p w) (@CMut.demonic_match_union N A Γ1 Γ2 U Δ p).
    Proof.
      intros t v ->.
      intros k k__c Hk.
      unfold SMut.demonic_match_union, CMut.demonic_match_union.
      eapply approx_bind; try (eapply approx_demonic_finite; assumption).
      intros w1 r01 ι1 -> Hpc1.
      intros v1 vc1 ->.
      eapply approx_bind; try (eapply approx_demonic; assumption).
      intros w2 r12 ι2 -> Hpc2.
      intros v2 vc2 ->.
      eapply approx_bind_right.
      - eapply approx_assume_formula; try assumption. cbn - [Val].
        change (inst v1 _) with v1.
        change (inst_term ?t ?ι) with (inst t ι).
        rewrite (inst_persist (AT := STerm _) (A := Val _)).
        now rewrite sub_acc_trans, inst_subst.
      - intros w3 r23 ι3 -> Hpc3.
        eapply approx_bind.
        + eapply approx_demonic_match_pattern; try assumption.
          now rewrite <- inst_persist.
        + change (inst v1 _) with v1.
          specialize (Hk v1).
          eapply (approx_four Hk).
          now rewrite ?sub_acc_trans, ?inst_subst.
    Qed.

    Lemma approx_demonic_match_bvec' {AT A} `{Approx AT A} {n : nat} {Γ1 Γ2 : PCtx}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_bvec' AT n Γ1 Γ2 w) (@CMut.demonic_match_bvec A n Γ1 Γ2).
    Proof.
      intros t v ->.
      intros ks kc Hk.
      unfold SMut.demonic_match_bvec', CMut.demonic_match_bvec.
      apply approx_bind.
      apply approx_demonic_finite; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros EK1 EK2 ->. unfold CMut.bind_right.
      apply approx_bind.
      apply approx_assume_formula; cbn; wsimpl; auto.
      now rewrite <- inst_persist.
      intros w2 ω12 ι2 -> Hpc2.
      intros _ _ _.
      eapply Hk; wsimpl; auto.
    Qed.

    Lemma approx_demonic_match_bvec {AT A} `{Approx AT A} {n : nat} {Γ1 Γ2 : PCtx}
      {w : World} (ι : Valuation w) (Hpc : instpc (wco w) ι) :
      approx ι (@SMut.demonic_match_bvec AT n Γ1 Γ2 w) (@CMut.demonic_match_bvec A n Γ1 Γ2).
    Proof.
      intros t v ->.
      intros c c__c Hc.
      unfold SMut.demonic_match_bvec.
      destruct (term_get_val_spec t).
      - intros P2 Pc2 HP2.
        intros c2 cc2 Hc2.
        intros s2 sc2 Hs2.
        hnf.
        rewrite CMut.wp_demonic_match_bvec.
        apply Hc; wsimpl; eauto.
      - apply approx_demonic_match_bvec'; auto.
    Qed.

  End PatternMatching.

  Section State.

    Lemma approx_pushpop {AT A} `{Approx AT A} {Γ1 Γ2 x σ} {w0 : World} (ι0 : Valuation w0)
          (Hpc : instpc (wco w0) ι0) :
      approx ι0 (@SMut.pushpop AT Γ1 Γ2 x σ w0) (@CMut.pushpop A Γ1 Γ2 x σ).
    Proof.
      intros t v ->.
      intros ms mc Hm.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 -> hs0 hc0 Hh0.
      unfold SMut.pushpop, CMut.pushpop.
      apply Hm; eauto.
      intros w1 ω01 ι1 -> Hpc1.
      intros a1 a Ha.
      intros δs1 δc1 -> hs1 hc1 Hh1.
      apply HPOST; auto.
      now destruct (env.snocView δs1).
    Qed.

    Lemma approx_pushspops {AT A} `{Approx AT A} {Γ1 Γ2 Δ} {w0 : World} (ι0 : Valuation w0)
          (Hpc : instpc (wco w0) ι0) :
      approx ι0 (@SMut.pushspops AT Γ1 Γ2 Δ w0) (@CMut.pushspops A Γ1 Γ2 Δ).
    Proof.
      intros δΔ ? ->.
      intros ms mc Hm.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 -> hs0 hc0 Hh0.
      unfold SMut.pushspops, CMut.pushspops.
      apply Hm; auto.
      - intros w1 ω01 ι1 -> Hpc1.
        intros a1 a Ha.
        intros δs1 δc1 -> hs1 hc1 ->.
        apply HPOST; auto.
        destruct (env.catView δs1).
        hnf.
        unfold inst, inst_store, inst_env at 1.
        rewrite <- env.map_drop.
        rewrite ?env.drop_cat.
        reflexivity.
      - hnf.
        unfold inst, inst_store, inst_env at 3.
        rewrite env.map_cat.
        reflexivity.
    Qed.

    Lemma approx_get_local {Γ}
      {w0 : World} (ι0 : Valuation w0) (Hpc : instpc (wco w0) ι0) :
      approx ι0 (@SMut.get_local Γ w0) (@CMut.get_local Γ).
    Proof.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 Hδ hs0 hc0 Hh0.
      unfold SMut.get_local, CMut.get_local.
      apply HPOST; wsimpl; auto.
    Qed.

    Lemma approx_put_local {Γ1 Γ2}
      {w0 : World} (ι0 : Valuation w0) (Hpc : instpc (wco w0) ι0) :
      approx ι0 (@SMut.put_local Γ1 Γ2 w0) (@CMut.put_local Γ1 Γ2).
    Proof.
      intros δs2 δc2 Hδ2.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 Hδ hs0 hc0 Hh0.
      unfold SMut.put_local, CMut.put_local.
      apply HPOST; wsimpl; auto.
    Qed.

    Lemma approx_get_heap {Γ}
      {w0 : World} (ι0 : Valuation w0) (Hpc : instpc (wco w0) ι0) :
      approx ι0 (@SMut.get_heap Γ w0) (@CMut.get_heap Γ).
    Proof.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 Hδ hs0 hc0 Hh0.
      unfold SMut.get_heap, CMut.get_heap.
      apply HPOST; wsimpl; auto.
    Qed.

    Lemma approx_put_heap {Γ}
      {w0 : World} (ι0 : Valuation w0) (Hpc : instpc (wco w0) ι0) :
      approx ι0 (@SMut.put_heap Γ w0) (@CMut.put_heap Γ).
    Proof.
      intros hs hc Hh.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 Hδ hs0 hc0 Hh0.
      unfold SMut.put_heap, CMut.put_heap.
      apply HPOST; wsimpl; auto.
    Qed.

    Lemma approx_eval_exp {Γ σ} (e : Exp Γ σ)
      {w0 : World} (ι0 : Valuation w0) (Hpc : instpc (wco w0) ι0) :
      approx ι0 (@SMut.eval_exp Γ σ e w0) (@CMut.eval_exp Γ σ e).
    Proof.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 -> hs0 hc0 Hh.
      apply HPOST; wsimpl; rewrite ?inst_sub_id; auto.
      hnf. now rewrite peval_sound, eval_exp_inst.
    Qed.

    Lemma approx_eval_exps {Γ Δ} (es : NamedEnv (Exp Γ) Δ) {w0 : World} (ι0 : Valuation w0)
          (Hpc : instpc (wco w0) ι0) :
      approx ι0 (@SMut.eval_exps Γ Δ es w0) (@CMut.eval_exps Γ Δ es).
    Proof.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 -> hs0 hc0 Hh.
      apply HPOST; auto. cbn. rewrite ?inst_sub_id; auto.
      apply env.lookup_extensional; cbn; intros [x σ] xIn.
      unfold evals, inst, inst_store, inst_env. rewrite ?env.lookup_map.
      now rewrite peval_sound, <- eval_exp_inst.
    Qed.

    Lemma approx_assign {Γ x σ} {xIn : x∷σ ∈ Γ}
      {w0 : World} (ι0 : Valuation w0) (Hpc : instpc (wco w0) ι0) :
      approx ι0 (@SMut.assign Γ x σ xIn w0) (@CMut.assign Γ x σ xIn).
    Proof.
      intros t v ->.
      intros POST__s POST__c HPOST.
      intros δs0 δc0 -> hs0 hc0 Hh.
      unfold SMut.assign, CMut.assign.
      apply HPOST; wsimpl; eauto.
      hnf. unfold inst, inst_store, inst_env.
      now rewrite env.map_update.
    Qed.

  End State.
  Local Hint Resolve approx_eval_exp : core.
  Local Hint Resolve approx_eval_exps : core.
  Local Hint Resolve approx_pushpop : core.
  Local Hint Resolve approx_pushspops : core.
  Local Hint Resolve approx_debug : core.

  Local Hint Resolve approx_demonic : core.
  Local Hint Resolve approx_bind : core.
  Local Hint Resolve approx_angelic_ctx : core.
  Local Hint Resolve approx_bind_right : core.

  Lemma approx_produce_chunk {Γ} {w0 : World} (ι0 : Valuation w0)
    (Hpc0 : instpc (wco w0) ι0) :
    approx ι0 (@SMut.produce_chunk Γ w0) (CMut.produce_chunk).
  Proof.
    intros cs cc ->.
    intros POST__s POST__c HPOST.
    intros δs δc -> hs hc ->.
    unfold SMut.produce_chunk, CMut.produce_chunk.
    apply HPOST; cbn; rewrite ?inst_sub_id; auto.
    hnf. cbn. now rewrite peval_chunk_sound.
  Qed.

  Lemma inst_env_cat {T : Set} {AT : LCtx -> T -> Set} {A : T -> Set}
     {instAT : forall τ : T, Inst (fun Σ : LCtx => AT Σ τ) (A τ)}
     {Σ : LCtx} {Γ Δ : Ctx T} (EΓ : Env (fun τ => AT Σ τ) Γ) (EΔ : Env (fun τ => AT Σ τ) Δ)
     (ι : Valuation Σ) :
    inst (EΓ ►► EΔ) ι = inst EΓ ι ►► inst EΔ ι.
  Proof.
    unfold inst, inst_env; cbn.
    now rewrite env.map_cat.
  Qed.

  Lemma inst_sub_cat {Σ Γ Δ : LCtx} (ζΓ : Sub Γ Σ) (ζΔ : Sub Δ Σ) (ι : Valuation Σ) :
    inst (A := Valuation _) (ζΓ ►► ζΔ) ι = inst ζΓ ι ►► inst ζΔ ι.
  Proof.
    apply (@inst_env_cat (𝑺 ∷ Ty) (fun Σ b => Term Σ (type b))).
  Qed.

  Lemma approx_produce {Γ Σ0 pc0} (asn : Assertion Σ0) :
    let w0 := @MkWorld Σ0 pc0 in
    forall
      (ι0 : Valuation w0)
      (Hpc0 : instpc (wco w0) ι0),
      approx ι0 (@SMut.produce Γ w0 asn) (CMut.produce ι0 asn).
  Proof.
    induction asn; intros w0 * Hpc; cbn - [wctx Val].
    - now apply approx_box_assume_formula.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      now apply approx_produce_chunk.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      now apply approx_produce_chunk.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_demonic_match_bool; eauto.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_demonic_match_enum; auto.
      intros EK1 EK2 HEK. hnf in HEK. subst EK2.
      eauto.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_demonic_match_sum; auto.
      + intros w2 ω12 ι2 -> Hpc2.
        intros t v ->.
        apply IHasn1; cbn - [inst sub_wk1]; wsimpl; auto.
      + intros w2 ω12 ι2 -> Hpc2.
        intros t v ->.
        apply IHasn2; cbn - [inst sub_wk1]; wsimpl; auto.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_demonic_match_list; auto.
      eapply approx_four; eauto.
      intros w2 ω12 ι2 -> Hpc2.
      intros thead vhead ->.
      intros ttail vtail ->.
      apply IHasn2; cbn - [inst sub_wk1]; wsimpl; auto.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_demonic_match_prod; auto.
      intros w2 ω12 ι2 -> Hpc2.
      intros t1 v1 -> t2 v2 ->.
      apply IHasn; cbn - [inst sub_wk1]; wsimpl; auto.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_demonic_match_tuple; auto.
      intros w2 ω12 ι2 -> Hpc2.
      intros ts vs ->.
      apply IHasn; cbn - [Sub inst sub_wk1 sub_id sub_cat_left]; wsimpl; auto.
      { rewrite <- ?inst_subst.
        unfold NamedEnv.
        fold (@inst_sub Δ).
        fold (Sub Δ).
        rewrite <- inst_sub_cat.
        rewrite <- inst_subst.
        rewrite <- subst_sub_comp.
        rewrite sub_comp_cat_left.
        now rewrite ?inst_subst.
      }
      now rewrite inst_sub_cat, inst_subst.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_demonic_match_record; auto.
      intros w2 ω12 ι2 -> Hpc2.
      intros ts vs ->.
      apply IHasn; cbn - [Sub inst sub_wk1 sub_id sub_cat_left]; wsimpl; auto.
      { rewrite <- ?inst_subst.
        unfold NamedEnv.
        fold (@inst_sub Δ).
        fold (Sub Δ).
        rewrite <- inst_sub_cat.
        rewrite <- inst_subst.
        rewrite <- subst_sub_comp.
        rewrite sub_comp_cat_left.
        now rewrite ?inst_subst.
      }
      now rewrite inst_sub_cat, inst_subst.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_demonic_match_union; auto.
      intros UK.
      intros w2 ω12 ι2 -> Hpc2.
      intros ts vs ->.
      apply H; cbn - [Sub inst sub_wk1 sub_id sub_cat_left]; wsimpl; auto.
      { rewrite <- ?inst_subst.
        unfold NamedEnv.
        fold (@inst_sub (alt__ctx UK)).
        fold (Sub (alt__ctx UK)).
        rewrite <- inst_sub_cat.
        rewrite <- inst_subst.
        rewrite <- subst_sub_comp.
        rewrite sub_comp_cat_left.
        now rewrite ?inst_subst.
      }
      now rewrite inst_sub_cat, inst_subst.
    - intros w1 ω01 ι1 -> Hpc1.
      apply approx_bind_right; eauto.
      apply IHasn1; eauto.
    - intros w1 ω01 ι1 -> Hpc1.
      apply approx_demonic_binary;
        try apply IHasn1; try apply IHasn2;
        cbn - [inst sub_wk1];
        rewrite ?inst_sub_snoc, ?sub_acc_trans, ?inst_subst, ?inst_sub_wk1; eauto.
    - intros w1 ω01 ι1 -> Hpc1.
      apply approx_bind.
      apply approx_demonic; auto.
      intros w2 ω02 ι2 -> Hpc2. intros t v ->.
      apply IHasn; cbn - [inst sub_wk1];
        rewrite ?inst_sub_snoc, ?sub_acc_trans, ?inst_subst, ?inst_sub_wk1; eauto.
    - intros w1 ω01 ι1 -> Hpc1.
      apply approx_debug; auto.
      apply approx_pure; auto.
  Qed.

  Lemma try_consume_chunk_exact_spec {Σ} (h : SHeap Σ) (c : Chunk Σ) :
    option.wlp
      (fun h' => List.In (c , h') (heap_extractions h))
      (SMut.try_consume_chunk_exact h c).
  Proof.
    induction h as [|c' h].
    - now constructor.
    - cbn -[is_duplicable].
      destruct (chunk_eqb_spec c c').
      + constructor. left. subst.
        remember (is_duplicable c') as dup.
        destruct dup; reflexivity.
      + apply option.wlp_map. revert IHh.
        apply option.wlp_monotonic; auto.
        intros h' HIn. right.
        rewrite List.in_map_iff.
        exists (c,h'). auto.
  Qed.

  Lemma inst_is_duplicable {w : World} (c : Chunk w) (ι : Valuation w) :
    is_duplicable (inst c ι) = is_duplicable c.
  Proof.
    destruct c; now cbn.
  Qed.

  Lemma inst_eq_rect {I} {T : I -> LCtx -> Type} {A : I -> Type}
    {instTA : forall i, Inst (T i) (A i)} (i j : I) (e : j = i) :
    forall Σ (t : T j Σ) (ι : Valuation Σ),
      inst (eq_rect j (fun i => T i Σ) t i e) ι =
      eq_rect j A (inst t ι) i e.
  Proof. now destruct e. Qed.

  Lemma inst_eq_rect_r {I} {T : I -> LCtx -> Type} {A : I -> Type}
    {instTA : forall i, Inst (T i) (A i)} (i j : I) (e : i = j) :
    forall Σ (t : T j Σ) (ι : Valuation Σ),
      inst (eq_rect_r (fun i => T i Σ) t e) ι = eq_rect_r A (inst t ι) e.
  Proof. now destruct e. Qed.

  Lemma find_chunk_user_precise_spec {Σ p ΔI ΔO} (prec : 𝑯_Ty p = ΔI ▻▻ ΔO) (tsI : Env (Term Σ) ΔI) (tsO : Env (Term Σ) ΔO) (h : SHeap Σ) :
    option.wlp
      (fun '(h', eqs) =>
         forall ι : Valuation Σ, instpc eqs ι ->
           List.In
             (inst (chunk_user p (eq_rect_r (fun c : Ctx Ty => Env (Term Σ) c) (tsI ►► tsO) prec)) ι, inst h' ι)
             (heap_extractions (inst h ι)))
      (SMut.find_chunk_user_precise prec tsI tsO h).
  Proof.
    induction h as [|c h]; [now constructor|]. cbn [SMut.find_chunk_user_precise].
    destruct SMut.match_chunk_user_precise as [eqs|] eqn:?.
    - clear IHh. constructor. intros ι Heqs. left.
      destruct c; try discriminate Heqo. cbn in *.
      destruct (eq_dec p p0); cbn in Heqo; try discriminate Heqo. destruct e.
      remember (eq_rect (𝑯_Ty p) (Env (Term Σ)) ts (ΔI ▻▻ ΔO) prec) as ts'.
      destruct (env.catView ts') as [tsI' tsO'].
      destruct (env.eqb_hom_spec Term_eqb (@Term_eqb_spec Σ) tsI tsI'); try discriminate.
      apply noConfusion_inv in Heqo. cbn in Heqo. subst.
      apply inst_formula_eqs_ctx in Heqs.
      rewrite (@inst_eq_rect_r (Ctx Ty) (fun Δ Σ => Env (Term Σ) Δ) (Env Val)).
      rewrite inst_env_cat. rewrite Heqs. rewrite <- inst_env_cat.
      change (env.cat ?A ?B) with (env.cat A B). rewrite Heqts'.
      rewrite (@inst_eq_rect (Ctx Ty) (fun Δ Σ => Env (Term Σ) Δ) (Env Val)).
      rewrite rew_opp_l. now destruct is_duplicable.
    - apply option.wlp_map. revert IHh. apply option.wlp_monotonic; auto.
      intros [h' eqs] HYP ι Heqs. specialize (HYP ι Heqs).
      remember (inst (chunk_user p (eq_rect_r (fun c0 : Ctx Ty => Env (Term Σ) c0) (tsI ►► tsO) prec)) ι) as c'.
      change (inst (cons c h) ι) with (cons (inst c ι) (inst h ι)).
      cbn [fst heap_extractions]. right. apply List.in_map_iff.
      eexists (c', inst h' ι); auto.
  Qed.

  Lemma find_chunk_ptsreg_precise_spec {Σ σ} (r : 𝑹𝑬𝑮 σ) (t : Term Σ σ) (h : SHeap Σ) :
    option.wlp
      (fun '(h', eqs) =>
         forall ι : Valuation Σ, instpc eqs ι ->
           List.In
             (inst (chunk_ptsreg r t) ι, inst h' ι)
             (heap_extractions (inst h ι)))
      (SMut.find_chunk_ptsreg_precise r t h).
  Proof.
    induction h; cbn [SMut.find_chunk_ptsreg_precise]; [now constructor|].
    destruct SMut.match_chunk_ptsreg_precise eqn:?.
    - constructor. intros ι. rewrite inst_pathcondition_cons. intros [Hf Hpc].
      clear IHh. destruct a; cbn in Heqo; try discriminate Heqo.
      destruct (eq_dec_het r r0); try discriminate Heqo.
      dependent elimination e. cbn in Heqo. dependent elimination Heqo.
      change (inst (cons ?c ?h) ι) with (cons (inst c ι) (inst h ι)).
      cbn. left. f_equal. f_equal. symmetry. exact Hf.
    - apply option.wlp_map. revert IHh. apply option.wlp_monotonic; auto.
      intros [h' eqs] HYP ι Heqs. specialize (HYP ι Heqs).
      remember (inst (chunk_ptsreg r t) ι) as c'.
      change (inst (cons ?c ?h) ι) with (cons (inst c ι) (inst h ι)).
      cbn [fst heap_extractions]. right. apply List.in_map_iff.
      eexists (c', inst h' ι); auto.
  Qed.

  Lemma approx_consume_chunk {Γ} {w0 : World} (ι0 : Valuation w0)
    (Hpc0 : instpc (wco w0) ι0) :
    approx ι0 (@SMut.consume_chunk Γ w0) (CMut.consume_chunk).
  Proof.
    intros cs cc ->.
    unfold SMut.consume_chunk, CMut.consume_chunk.
    apply approx_bind.
    apply approx_get_heap; auto.
    intros w1 ω01 ι1 -> Hpc1.
    intros hs hc ->.
    remember (peval_chunk (persist cs ω01)) as c1.
    destruct (try_consume_chunk_exact_spec hs c1) as [h' HIn|].
    { intros POST__s POST__c HPOST.
      intros δs δc -> hs' hc' ->.
      unfold approx, ApproxPath. intros Hwp.
      cbv [SMut.put_heap CMut.bind CMut.put_heap CMut.bind_right CMut.assert_formula
                         T CMut.angelic_list CMut.dijkstra].
      rewrite CDijk.wp_angelic_list.
      change (SHeap w1) in h'.
      exists (inst c1 ι1, inst h' ι1).
      split.
      - unfold inst at 3, inst_heap, inst_list.
        rewrite heap_extractions_map, List.in_map_iff.
        + exists (c1 , h'). split. reflexivity. assumption.
        + eauto using inst_is_duplicable.
      - hnf. subst. rewrite peval_chunk_sound, inst_persist.
        split; auto. revert Hwp. apply HPOST; wsimpl; auto.
    }
    destruct (SMut.try_consume_chunk_precise hs c1) as [[h' eqs]|] eqn:?.
    { intros POST__s POST__c HPOST.
      intros δs δc -> hs' hc' ->.
      unfold approx, ApproxPath.
      cbv [SMut.put_heap SMut.bind_right T]. cbn. intros Hwp.
      eapply (approx_assert_formulas Hpc1 eqs) in Hwp; eauto. destruct Hwp as [Heqs HPOST1].
      cbv [CMut.bind CMut.put_heap CMut.bind_right CMut.assert_formula
           T CMut.angelic_list CMut.dijkstra].
      rewrite CDijk.wp_angelic_list.
      destruct c1; cbn in Heqo; try discriminate Heqo; cbn.
      - destruct (𝑯_precise p) as [[ΔI ΔO prec]|]; try discriminate Heqo.
        remember (eq_rect (𝑯_Ty p) (Env (Term w1)) ts (ΔI ▻▻ ΔO) prec) as ts'.
        destruct (env.catView ts') as [tsI tsO].
        destruct (find_chunk_user_precise_spec prec tsI tsO hs) as [[h'' eqs''] HIn|];
          inversion Heqo; subst; clear Heqo.
        specialize (HIn ι1 Heqs). rewrite Heqts' in HIn.
        rewrite rew_opp_l in HIn. rewrite Heqc1 in HIn.
        rewrite peval_chunk_sound in HIn.
        eexists; split; eauto. clear HIn.
        hnf. split; auto. now rewrite <- inst_persist.
      - destruct (find_chunk_ptsreg_precise_spec r t hs) as [[h'' eqs''] HIn|];
          inversion Heqo; subst; clear Heqo.
        specialize (HIn ι1 Heqs). rewrite Heqc1 in HIn.
        rewrite peval_chunk_sound in HIn.
        eexists; split; eauto. clear HIn.
        hnf. split; auto. now rewrite <- inst_persist.
    }
    { intros POST__s POST__c HPOST.
      intros δs δc ? hs' hc' ? [].
    }
  Qed.

  Lemma approx_consume_chunk_angelic {Γ} {w0 : World} (ι0 : Valuation w0)
    (Hpc0 : instpc (wco w0) ι0) :
    approx ι0 (@SMut.consume_chunk_angelic Γ w0) (CMut.consume_chunk).
  Proof.
    intros cs cc ->.
    unfold SMut.consume_chunk_angelic, CMut.consume_chunk.
    apply approx_bind.
    apply approx_get_heap; auto.
    intros w1 ω01 ι1 -> Hpc1.
    intros hs hc ->.
    remember (peval_chunk (persist cs ω01)) as c1.
    destruct (try_consume_chunk_exact_spec hs c1) as [h' HIn|].
    { intros POST__s POST__c HPOST.
      intros δs δc -> hs' hc' ->.
      unfold approx, ApproxPath. intros Hwp.
      cbv [SMut.put_heap CMut.bind CMut.put_heap CMut.bind_right CMut.assert_formula
                         T CMut.angelic_list CMut.dijkstra].
      rewrite CDijk.wp_angelic_list.
      change (SHeap w1) in h'.
      exists (inst c1 ι1, inst h' ι1).
      split.
      - unfold inst at 3, inst_heap, inst_list.
        rewrite heap_extractions_map, List.in_map_iff.
        + exists (c1 , h'). split. reflexivity. assumption.
        + eauto using inst_is_duplicable.
      - hnf. subst. rewrite peval_chunk_sound, inst_persist.
        split; auto. revert Hwp. apply HPOST; wsimpl; auto.
    }
    destruct (SMut.try_consume_chunk_precise hs c1) as [[h' eqs]|] eqn:?.
    { intros POST__s POST__c HPOST.
      intros δs δc -> hs' hc' ->.
      unfold approx, ApproxPath.
      cbv [SMut.put_heap SMut.bind_right T]. cbn. intros Hwp.
      eapply (approx_assert_formulas Hpc1 eqs) in Hwp; eauto. destruct Hwp as [Heqs HPOST1].
      cbv [CMut.bind CMut.put_heap CMut.bind_right CMut.assert_formula
           T CMut.angelic_list CMut.dijkstra].
      rewrite CDijk.wp_angelic_list.
      destruct c1; cbn in Heqo; try discriminate Heqo; cbn.
      - destruct (𝑯_precise p) as [[ΔI ΔO prec]|]; try discriminate Heqo.
        remember (eq_rect (𝑯_Ty p) (Env (Term w1)) ts (ΔI ▻▻ ΔO) prec) as ts'.
        destruct (env.catView ts') as [tsI tsO].
        destruct (find_chunk_user_precise_spec prec tsI tsO hs) as [[h'' eqs''] HIn|];
          inversion Heqo; subst; clear Heqo.
        specialize (HIn ι1 Heqs). rewrite Heqts' in HIn.
        rewrite rew_opp_l in HIn. rewrite Heqc1 in HIn.
        rewrite peval_chunk_sound in HIn.
        eexists; split; eauto. clear HIn.
        hnf. split; auto. now rewrite <- inst_persist.
      - destruct (find_chunk_ptsreg_precise_spec r t hs) as [[h'' eqs''] HIn|];
          inversion Heqo; subst; clear Heqo.
        specialize (HIn ι1 Heqs). rewrite Heqc1 in HIn.
        rewrite peval_chunk_sound in HIn.
        eexists; split; eauto. clear HIn.
        hnf. split; auto. now rewrite <- inst_persist.
    }
    { apply approx_bind.
      eapply approx_angelic_list; eauto.
      { hnf. unfold inst at 1, inst_heap, inst_list.
        rewrite heap_extractions_map.
        apply List.map_ext. now intros [].
        eauto using inst_is_duplicable.
      }
      intros w2 ω12 ι2 -> Hpc2.
      intros [cs' hs'] [cc' hc'].
      intros Hch'. inversion Hch'; subst; clear Hch'.
      apply approx_bind_right.
      - apply approx_assert_formulas; auto.
        rewrite SMut.inst_match_chunk.
        now rewrite inst_persist, peval_chunk_sound, inst_persist.
      - intros w3 ω23 ι3 -> Hpc3.
        rewrite <- inst_persist.
        apply approx_put_heap; auto.
    }
  Qed.

  Lemma approx_consume {Γ Σ0 pc0} (asn : Assertion Σ0) :
    let w0 := @MkWorld Σ0 pc0 in
    forall
      (ι0 : Valuation w0)
      (Hpc0 : instpc (wco w0) ι0),
      approx ι0 (@SMut.consume Γ w0 asn) (CMut.consume ι0 asn).
  Proof.
    induction asn; intros w0 * Hpc; cbn - [wctx Val].
    - now apply approx_box_assert_formula.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      now apply approx_consume_chunk.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      now apply approx_consume_chunk_angelic.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_angelic_match_bool; eauto.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_angelic_match_enum; auto.
      intros EK1 EK2 HEK. hnf in HEK. subst EK2.
      eauto.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_angelic_match_sum; auto.
      + intros w2 ω12 ι2 -> Hpc2.
        intros t v ->.
        apply IHasn1; cbn - [inst sub_wk1]; wsimpl; auto.
      + intros w2 ω12 ι2 -> Hpc2.
        intros t v ->.
        apply IHasn2; cbn - [inst sub_wk1]; wsimpl; auto.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_angelic_match_list; auto.
      eapply approx_four; eauto.
      intros w2 ω12 ι2 -> Hpc2.
      intros thead vhead ->.
      intros ttail vtail ->.
      apply IHasn2; cbn - [inst sub_wk1]; wsimpl; auto.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_angelic_match_prod; auto.
      intros w2 ω12 ι2 -> Hpc2.
      intros t1 v1 -> t2 v2 ->.
      apply IHasn; cbn - [inst sub_wk1]; wsimpl; auto.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_angelic_match_tuple; auto.
      intros w2 ω12 ι2 -> Hpc2.
      intros ts vs ->.
      apply IHasn; cbn - [Sub inst sub_wk1 sub_id sub_cat_left]; wsimpl; auto.
      { rewrite <- ?inst_subst.
        unfold NamedEnv.
        fold (@inst_sub Δ).
        fold (Sub Δ).
        rewrite <- inst_sub_cat.
        rewrite <- inst_subst.
        rewrite <- subst_sub_comp.
        rewrite sub_comp_cat_left.
        now rewrite ?inst_subst.
      }
      now rewrite inst_sub_cat, inst_subst.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_angelic_match_record; auto.
      intros w2 ω12 ι2 -> Hpc2.
      intros ts vs ->.
      apply IHasn; cbn - [Sub inst sub_wk1 sub_id sub_cat_left]; wsimpl; auto.
      { rewrite <- ?inst_subst.
        unfold NamedEnv.
        fold (@inst_sub Δ).
        fold (Sub Δ).
        rewrite <- inst_sub_cat.
        rewrite <- inst_subst.
        rewrite <- subst_sub_comp.
        rewrite sub_comp_cat_left.
        now rewrite ?inst_subst.
      }
      now rewrite inst_sub_cat, inst_subst.
    - intros w1 ω01 ι1 -> Hpc1.
      rewrite <- inst_persist.
      apply approx_angelic_match_union; auto.
      intros UK.
      intros w2 ω12 ι2 -> Hpc2.
      intros ts vs ->.
      apply H; cbn - [Sub inst sub_wk1 sub_id sub_cat_left]; wsimpl; auto.
      { rewrite <- ?inst_subst.
        unfold NamedEnv.
        fold (@inst_sub (alt__ctx UK)).
        fold (Sub (alt__ctx UK)).
        rewrite <- inst_sub_cat.
        rewrite <- inst_subst.
        rewrite <- subst_sub_comp.
        rewrite sub_comp_cat_left.
        now rewrite ?inst_subst.
      }
      now rewrite inst_sub_cat, inst_subst.
    - intros w1 ω01 ι1 -> Hpc1.
      apply approx_bind_right; eauto.
      apply IHasn1; eauto.
    - intros w1 ω01 ι1 -> Hpc1.
      apply approx_angelic_binary;
        try apply IHasn1; try apply IHasn2;
        cbn - [inst sub_wk1];
        rewrite ?inst_sub_snoc, ?sub_acc_trans, ?inst_subst, ?inst_sub_wk1; eauto.
    - intros w1 ω01 ι1 -> Hpc1.
      apply approx_bind.
      apply approx_angelic; auto.
      intros w2 ω02 ι2 -> Hpc2. intros t v ->.
      apply IHasn; cbn - [inst sub_wk1];
        rewrite ?inst_sub_snoc, ?sub_acc_trans, ?inst_subst, ?inst_sub_wk1; eauto.
    - intros w1 ω01 ι1 -> Hpc1.
      apply approx_debug; auto.
      apply approx_pure; auto.
  Qed.

  Lemma approx_call_contract {Γ Δ : PCtx} {τ : Ty} (c : SepContract Δ τ) :
    forall {w0 : World} {ι0 : Valuation w0} (Hpc0 : instpc (wco w0) ι0),
      approx ι0 (@SMut.call_contract Γ Δ τ c w0) (@CMut.call_contract Γ Δ τ c).
  Proof.
    destruct c; cbv [SMut.call_contract CMut.call_contract].
    intros w0 ι0 Hpc0.
    intros args__s args__c Hargs.
    apply approx_bind; auto.
    intros w1 ω01 ι1 -> Hpc1.
    intros evars__s evars__c Hevars.
    apply approx_bind_right.
    apply approx_assert_formulas; auto.
    { rewrite inst_formula_eqs_nctx.
      rewrite inst_persist, inst_subst.
      rewrite Hargs, Hevars.
      reflexivity.
    }
    intros w2 ω12 ι2 -> Hpc2.
    apply approx_bind_right.
    { apply approx_consume; wsimpl; auto.
      constructor.
    }
    intros w3 ω23 ι3 -> Hpc3.
    apply approx_bind.
    { apply approx_demonic; auto. }
    intros w4 ω34 ι4 -> Hpc4.
    intros res__s res__c Hres.
    apply approx_bind_right.
    { apply approx_produce; auto.
      constructor.
      cbn - [inst_env sub_snoc].
      rewrite inst_sub_snoc, inst_persist, ?sub_acc_trans, ?inst_subst.
      now rewrite Hevars, Hres.
    }
    intros w5 ω45 ι5 -> Hpc5.
    apply approx_pure; auto.
    rewrite Hres. rewrite <- inst_persist.
    reflexivity.
  Qed.

  Lemma approx_call_lemma {Γ Δ : PCtx} (lem : Lemma Δ) :
    forall {w0 : World} {ι0 : Valuation w0} (Hpc0 : instpc (wco w0) ι0),
      approx ι0 (@SMut.call_lemma Γ Δ lem w0) (@CMut.call_lemma Γ Δ lem).
  Proof.
    destruct lem; cbv [SMut.call_lemma CMut.call_lemma].
    intros w0 ι0 Hpc0.
    intros args__s args__c Hargs.
    apply approx_bind; auto.
    intros w1 ω01 ι1 -> Hpc1.
    intros evars__s evars__c Hevars.
    apply approx_bind_right.
    apply approx_assert_formulas; auto.
    { rewrite inst_formula_eqs_nctx.
      rewrite inst_persist, inst_subst.
      rewrite Hargs, Hevars.
      reflexivity.
    }
    intros w2 ω12 ι2 -> Hpc2.
    apply approx_bind_right.
    { apply approx_consume; wsimpl; auto.
      constructor.
    }
    intros w3 ω23 ι3 -> Hpc3.
    { apply approx_produce; auto.
      constructor.
      cbn - [inst_env sub_snoc].
      rewrite inst_persist, sub_acc_trans, inst_subst.
      now rewrite Hevars.
    }
  Qed.

  Definition ExecApprox (sexec : SMut.Exec) (cexec : CMut.Exec) :=
    forall Γ τ (s : Stm Γ τ) (w0 : World) (ι0 : Valuation w0) (Hpc0 : instpc (wco w0) ι0),
    approx ι0 (@sexec Γ τ s w0) (cexec Γ τ s).

  Lemma approx_exec_aux {cfg} srec crec (HYP : ExecApprox srec crec) :
    ExecApprox (@SMut.exec_aux cfg srec) (@CMut.exec_aux crec).
  Proof.
    unfold ExecApprox.
    induction s; cbn; intros * ?.
    - apply approx_pure; auto.
    - now apply approx_eval_exp.
    - apply approx_bind; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v Htv.
      apply approx_pushpop; auto.
    - apply approx_pushspops; auto.
      apply approx_lift.
    - apply approx_bind; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v ->.
      apply approx_bind_right.
      apply approx_assign; auto.
      intros w2 ω12 ι2 -> Hpc2.
      rewrite <- inst_subst.
      apply approx_pure; auto.
    - apply approx_bind.
      apply approx_eval_exps; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros args__s args__c Hargs.
      destruct (CEnv f).
      + unfold SMut.call_contract_debug.
        destruct (config_debug_function cfg f).
        apply approx_debug; auto.
        apply approx_call_contract; auto.
        apply approx_call_contract; auto.
      + intros POST__s POST__c HPOST.
        intros δs1 δc1 ->.
        apply HYP; auto.
        intros w2 ω12 ι2 -> Hpc2.
        intros t v ->.
        intros _ _ _.
        apply HPOST; auto.
        rewrite <- inst_persist.
        reflexivity.
    - apply approx_bind.
      apply approx_get_local; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros δs1 δc1 ->.
      apply approx_bind_right.
      apply approx_put_local; auto.
      apply approx_lift.
      intros w2 ω12 ι2 -> Hpc2.
      apply approx_bind; auto.
      intros w3 ω23 ι3 -> Hpc3.
      intros t v ->.
      apply approx_bind_right.
      apply approx_put_local; auto.
      rewrite persist_subst.
      hnf. rewrite sub_acc_trans, ?inst_subst; auto.
      intros w4 ω34 ι4 -> Hpc4.
      rewrite <- inst_persist.
      apply approx_pure; auto.
    - apply approx_bind.
      apply approx_eval_exps; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros args__s args__c Hargs.
      apply approx_call_contract; auto.
    - apply approx_bind_right; auto.
      apply approx_bind.
      apply approx_eval_exps; auto.
      intros w1 ω01 ι1 -> Hpc1.
      apply approx_call_lemma; auto.
    - apply approx_bind.
      intros POST__s POST__c HPOST.
      apply approx_eval_exp; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v Htv.
      apply approx_demonic_match_bool; auto.
    - apply approx_bind_right; auto.
    - apply approx_bind; auto.
      intros POST__s POST__c HPOST.
      apply approx_eval_exp; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v ->.
      apply approx_bind_right.
      apply approx_assume_formula; auto.
      intros w2 ω12 ι2 -> Hpc2.
      now apply IHs.
    - apply approx_block.
    - apply approx_bind; auto.
      intros POST__s POST__c HPOST.
      apply approx_eval_exp; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v Htv.
      apply approx_demonic_match_list; auto.
      intros w2 ω12 ι2 -> Hpc2.
      intros thead vhead ->.
      intros ttail vtail ->.
      apply approx_pushspops; auto.
    - apply approx_bind; auto.
      intros POST__s POST__c HPOST.
      apply approx_eval_exp; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v Htv.
      apply approx_demonic_match_sum; auto.
      + intros w2 ω12 ι2 -> Hpc2.
        intros tl vl ->.
        apply approx_pushpop; auto.
      + intros w2 ω12 ι2 -> Hpc2.
        intros tr vr ->.
        apply approx_pushpop; auto.
    - apply approx_bind; auto.
      intros POST__s POST__c HPOST.
      apply approx_eval_exp; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v Htv.
      apply approx_demonic_match_prod; auto.
      intros w2 ω12 ι2 -> Hpc2.
      intros t1 v1 ->.
      intros t2 v2 ->.
      apply approx_pushspops; auto.
    - apply approx_bind; auto.
      intros POST__s POST__c HPOST.
      apply approx_eval_exp; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v Htv.
      apply approx_demonic_match_enum; auto.
      intros EK1 EK2 ->.
      intros w2 ω12 ι2 -> Hpc2; auto.
    - apply approx_bind; auto.
      intros POST__s POST__c HPOST.
      apply approx_eval_exp; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v Htv.
      apply approx_demonic_match_tuple; auto.
      intros w2 ω12 ι2 -> Hpc2.
      intros ts vs Htvs.
      apply approx_pushspops; auto.
    - apply approx_bind; auto.
      intros POST__s POST__c HPOST.
      apply approx_eval_exp; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v Htv.
      apply approx_demonic_match_union; auto.
      intros UK.
      intros w2 ω12 ι2 -> Hpc2.
      intros ts vs Htvs.
      apply approx_pushspops; auto.
    - apply approx_bind; auto.
      intros POST__s POST__c HPOST.
      apply approx_eval_exp; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v Htv.
      apply approx_demonic_match_record; auto.
      intros w2 ω12 ι2 -> Hpc2.
      intros ts vs Htvs.
      apply approx_pushspops; auto.
    - apply approx_bind; auto.
      intros POST__s POST__c HPOST.
      apply approx_eval_exp; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v Htv.
      apply approx_demonic_match_bvec; auto.
      intros v1 v2 ->.
      intros w2 ω12 ι2 -> Hpc2.
      auto.
    - apply approx_bind; auto.
      apply approx_angelic; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros t v ->.
      apply approx_bind_right; auto.
      apply approx_consume_chunk; auto.
      intros w2 ω12 ι2 -> Hpc2.
      apply approx_bind_right; auto.
      rewrite <- inst_persist.
      apply approx_produce_chunk; auto.
      intros w3 ω23 ι3 -> Hpc3.
      apply approx_pure; auto. hnf.
      rewrite (persist_trans (A := STerm _)).
      now rewrite <- ?inst_persist.
    - apply approx_bind; auto.
      apply approx_angelic; auto.
      intros w1 ω01 ι1 -> Hpc1.
      intros told v ->.
      apply approx_bind_right; auto.
      apply approx_consume_chunk; auto.
      intros w2 ω12 ι2 -> Hpc2.
      apply approx_bind; auto.
      intros w3 ω23 ι3 -> Hpc3.
      intros tnew v ->.
      apply approx_bind_right; auto.
      apply approx_produce_chunk; auto.
      intros w4 ω34 ι4 -> Hpc4.
      apply approx_pure; auto.
      now rewrite <- inst_persist.
    - apply approx_error.
    - apply approx_debug; auto.
  Qed.

  Lemma approx_exec {cfg n} :
    ExecApprox (@SMut.exec cfg n) (@CMut.exec n).
  Proof.
    induction n; cbn.
    - unfold ExecApprox. intros.
      intros POST__s POST__c HPOST.
      intros δs1 δc1 Hδ hs1 hc1 Hh.
      hnf. contradiction.
    - now apply approx_exec_aux.
  Qed.

  Lemma approx_exec_contract {cfg : Config} n {Γ τ} (c : SepContract Γ τ) (s : Stm Γ τ) :
    let w0 := {| wctx := sep_contract_logic_variables c; wco := nil |} in
    forall (ι0 : Valuation w0),
      approx (w := w0) ι0 (@SMut.exec_contract cfg n Γ τ c s) (@CMut.exec_contract n Γ τ c s ι0).
  Proof.
    unfold SMut.exec_contract, CMut.exec_contract; destruct c as [Σ δ pre result post]; cbn in *.
    intros ι0.
    apply approx_bind_right.
    apply approx_produce; wsimpl; cbn; auto.
    intros w1 ω01 ι1 -> Hpc1.
    apply approx_bind.
    apply approx_exec; auto.
    intros w2 ω12 ι2 -> Hpc2.
    intros res__s res__c Hres.
    apply approx_consume; cbn - [inst]; wsimpl; auto.
    constructor.
    f_equal; auto.
  Qed.

  Definition safe_demonic_close {Σ : LCtx} :
    forall p : 𝕊 Σ,
      safe (demonic_close p) env.nil ->
      forall ι : Valuation Σ,
        safe p ι.
  Proof.
    induction Σ; cbn [demonic_close] in *.
    - intros p Hwp ι.
      destruct (env.nilView ι). apply Hwp.
    - intros p Hwp ι.
      destruct b as [x σ], (env.snocView ι).
      now apply (IHΣ (demonicv (x∷σ) p)).
  Qed.

  Lemma approx_postprocessing_prune {w : World} (ι : Valuation w) (P : 𝕊 w) (p : Prop) :
    approx ι P p ->
    approx ι (Postprocessing.prune P) p.
  Proof.
    unfold approx, ApproxPath.
    now rewrite ?wsafe_safe, ?safe_debug_safe, Postprocessing.prune_sound.
  Qed.

  Lemma approx_postprocessing_solve_evars {w : World} (ι : Valuation w) (P : 𝕊 w) (p : Prop) :
    approx ι P p ->
    approx ι (Postprocessing.solve_evars P) p.
  Proof.
    unfold approx, ApproxPath.
    now rewrite ?wsafe_safe, ?safe_debug_safe, Postprocessing.solve_evars_sound.
  Qed.

  Lemma approx_postprocessing_solve_uvars {w : World} (ι : Valuation w) (P : 𝕊 w) (p : Prop) :
    approx ι P p ->
    approx ι (Postprocessing.solve_uvars P) p.
  Proof.
    unfold approx, ApproxPath.
    rewrite ?wsafe_safe, ?safe_debug_safe.
    auto using Postprocessing.solve_uvars_sound.
  Qed.

  Lemma approx_demonic_close {w : World} (P : 𝕊 w) (p : Valuation w -> Prop) :
    (forall (ι : Valuation w), approx ι P (p ι)) ->
    approx (w := wnil) env.nil (demonic_close P) (ForallNamed p).
  Proof.
    unfold approx, ApproxPath, ForallNamed. intros HYP Hwp.
    rewrite env.Forall_forall. intros ι.
    apply HYP. revert Hwp. clear.
    rewrite ?wsafe_safe, ?safe_debug_safe.
    intros Hwp. now apply safe_demonic_close.
  Qed.

  Lemma approx_vcgen {Γ τ} (c : SepContract Γ τ) (body : Stm Γ τ) :
    approx (w := wnil) env.nil (SMut.VcGen c body) (CMut.ValidContract 1 c body).
  Proof.
    unfold SMut.VcGen.
    apply approx_postprocessing_prune.
    apply approx_postprocessing_solve_uvars.
    apply approx_postprocessing_prune.
    apply approx_postprocessing_solve_evars.
    apply approx_postprocessing_prune.
    unfold SMut.exec_contract_path, CMut.ValidContract.
    apply (approx_demonic_close
             (w := {| wctx := sep_contract_logic_variables c; wco := nil |})).
    intros ι.
    apply approx_exec_contract; auto.
    now intros w1 ω01 ι1 -> Hpc1.
  Qed.

  Lemma symbolic_sound {Γ τ} (c : SepContract Γ τ) (body : Stm Γ τ) :
    SMut.ValidContract c body ->
    CMut.ValidContract 1 c body.
  Proof.
    unfold SMut.ValidContract. intros [Hwp].
    apply approx_vcgen. now rewrite wsafe_safe, safe_debug_safe.
  Qed.

  (* Print Assumptions symbolic_sound. *)

End Soundness.
