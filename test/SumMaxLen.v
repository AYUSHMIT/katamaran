(******************************************************************************)
(* Copyright (c) 2022 Steven Keuchel                                          *)
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
     Lists.List
     Logic.FinFun
     Program.Tactics
     Strings.String
     ZArith.ZArith
     micromega.Lia.

From Equations Require Import
     Equations.

From Katamaran Require Import
     Iris.Model
     Semantics.Registers
     Sep.Hoare
     Shallow.Executor
     Shallow.Soundness
     Symbolic.Mutator
     Symbolic.Solver
     Symbolic.Sound
     Symbolic.Worlds
     Symbolic.Propositions
     Semantics
     Specification
     Syntax.Terms
     Program
     Syntax.Predicates
     Syntax.ContractDecl.

Set Implicit Arguments.
Import ctx.notations.
Import env.notations.
Open Scope string_scope.
Open Scope Z_scope.
Open Scope ctx_scope.

(*** PROGRAM ***)

Import DefaultBase.

Module Import ExampleProgram <: Program DefaultBase.

  Section FunDeclKit.

    Inductive Fun : PCtx -> Ty -> Set :=
    | summaxlen : Fun [ "xs" ∷ ty.list ty.int ] (ty.prod (ty.prod ty.int ty.int) ty.int)
    .

    Definition 𝑭  : PCtx -> Ty -> Set := Fun.
    Definition 𝑭𝑿 : PCtx -> Ty -> Set := fun _ _ => Empty_set.
    Definition 𝑳 : PCtx -> Set := fun _ => Empty_set.

  End FunDeclKit.

  Include FunDeclMixin DefaultBase.

  Section FunDefKit.
    Import ctx.resolution.

    Local Coercion stm_exp : Exp >-> Stm.
    Local Notation "'l'"   := (@exp_var _ "l" _ _) : exp_scope.
    Local Notation "'m'"   := (@exp_var _ "m" _ _) : exp_scope.
    Local Notation "'s'"   := (@exp_var _ "s" _ _) : exp_scope.
    Local Notation "'sm'"   := (@exp_var _ "sm" _ _) : exp_scope.
    Local Notation "'sml'"   := (@exp_var _ "sml" _ _) : exp_scope.
    Local Notation "'y'"   := (@exp_var _ "y" _ _) : exp_scope.
    Local Notation "'xs'"   := (@exp_var _ "xs" _ _) : exp_scope.
    Local Notation "'ys'"   := (@exp_var _ "ys" _ _) : exp_scope.

    Definition fun_summaxlen : Stm ["xs" ∷ ty.list ty.int] (ty.prod (ty.prod ty.int ty.int) ty.int) :=
      stm_match_list xs (stm_val (ty.prod (ty.prod ty.int ty.int) ty.int) (0,0,0))
        "y" "ys"
        (let: "sml" := call summaxlen ys in
         match: sml in (ty.prod ty.int ty.int , ty.int) with
         | ("sm","l") =>
           match: sm in (ty.int,ty.int) with
           | ("s","m") =>
             let: "m'" := if: m < y then y else m in
             exp_binop bop.pair (exp_binop bop.pair (s + y) (exp_var "m'")) (l + exp_int 1)
           end
         end).

    Definition fun_summaxlen_with_debug : Stm ["xs" ∷ ty.list ty.int] (ty.prod (ty.prod ty.int ty.int) ty.int) :=
      stm_match_list xs (stm_val (ty.prod (ty.prod ty.int ty.int) ty.int) (0,0,0))
        "y" "ys"
        (let: "sml" := call summaxlen ys in
         match: sml in (ty.prod ty.int ty.int , ty.int) with
         | ("sm","l") =>
             match: sm in (ty.int,ty.int) with
             | ("s","m") =>
                 let: "m'" := if: m < y then y else m in
                 stm_debugk (exp_binop bop.pair (exp_binop bop.pair (s + y) (exp_var "m'")) (l + exp_int 1))
             end
         end).

    Definition FunDef {Δ τ} (f : Fun Δ τ) : Stm Δ τ :=
      match f in Fun Δ τ return Stm Δ τ with
      | summaxlen => fun_summaxlen
      end.

  End FunDefKit.

  Include DefaultRegStoreKit DefaultBase.

  Section ForeignKit.
    Definition Memory : Set := unit.
    Definition ForeignCall {σs σ} (f : 𝑭𝑿 σs σ) (args : NamedEnv Val σs)
      (res : string + Val σ) (γ γ' : RegStore) (μ μ' : Memory) : Prop := False.
    Lemma ForeignProgress {σs σ} (f : 𝑭𝑿 σs σ) (args : NamedEnv Val σs) γ μ :
      exists γ' μ' res, ForeignCall f args res γ γ' μ μ'.
    Proof. destruct f. Qed.
  End ForeignKit.

  Include ProgramMixin DefaultBase.

End ExampleProgram.

Module Import ExampleSig <: ProgramLogicSignature DefaultBase.
  Module PROG := ExampleProgram.
  Import ctx.resolution.

  Include DefaultPredicateKit DefaultBase.
  Include ContractDeclMixin DefaultBase ExampleProgram.
  Include SpecificationMixin DefaultBase ExampleProgram.
End ExampleSig.

Module Import ExampleSpecification <: Specification DefaultBase ExampleSig.

  Import ctx.resolution.

  Definition sep_contract_summaxlen : SepContract [ "xs" ∷ ty.list ty.int ] (ty.prod (ty.prod ty.int ty.int) ty.int) :=
    {| sep_contract_logic_variables := ["xs" ∷ ty.list ty.int ];
       sep_contract_localstore      := [term_var "xs"];
       sep_contract_precondition    := asn_true;
       sep_contract_result          := "result";
       sep_contract_postcondition   :=
         asn_match_prod
           (term_var "result") "sm" "l"
           (asn_match_prod
              (term_var "sm") "s" "m"
              (asn_sep
                 (asn_formula (formula_le (term_var "s") (term_binop bop.times (term_var "m") (term_var "l"))))
                 (asn_formula (formula_le (term_val ty.int 0) (term_var "l")))));
    |}.

  Definition CEnv : SepContractEnv :=
    fun Δ τ f =>
      match f with
      | summaxlen => Some sep_contract_summaxlen
      end.

  Definition CEnvEx : SepContractEnvEx :=
    fun Δ τ f =>
      match f with end.

  Definition LEnv : LemmaEnv :=
    fun Δ l =>
      match l with end.

End ExampleSpecification.

Module ExampleSolverKit := DefaultSolverKit DefaultBase ExampleSig ExampleSpecification.
Module ExampleSolver := MakeSolver DefaultBase ExampleSig ExampleSpecification ExampleSolverKit.

Module Import ExampleExecutor :=
  MakeExecutor DefaultBase ExampleSig ExampleSpecification ExampleSolver.

Local Ltac solve :=
  repeat
    (repeat
       match goal with
       | H: _ /\ _ |- _ => destruct H
       | H: Z.ltb _ _ = true |- _ => apply Z.ltb_lt in H
       | H: Z.ltb _ _ = false |- _ => apply Z.ltb_ge in H
       | H: pair _ _ = pair _ _ |- _ => inversion H; subst; clear H
       | H: ?x = ?x |- _ => clear H
       | |- forall _, _ => intro
       | |- exists _, _ => eexists
       | |- _ /\ _ => constructor
       | |- _ = _  => reflexivity
       end;
     try progress subst);
  auto.

Module Import ExampleShalExec := MakeShallowExecutor DefaultBase ExampleSig ExampleSpecification.
Import CMut.

Goal True. idtac "Timing before: summaxlen/shallow". Abort.
Lemma valid_contract_summaxlen_shallow : CMut.ValidContract 1 sep_contract_summaxlen fun_summaxlen.
Proof.
  compute - [negb Z.mul Z.opp Z.compare Z.add Z.geb Z.eqb Z.leb Z.gtb Z.ltb Z.le Z.lt Z.gt Z.ge].
  solve; nia.
Qed.
Goal True. idtac "Timing after: summaxlen/shallow". Abort.

(* Goal True. idtac "Timing before: summaxlen/slow". Abort. *)
(* Lemma valid_contract_summaxlen_slow : SMut.ValidContract sep_contract_summaxlen fun_summaxlen. *)
(* Proof. *)
(*   compute. constructor. *)
(*   compute - [Z.mul Z.add Z.le Z.ge Z.lt]. *)
(*   solve; nia. *)
(* Time Qed. *)
(* Goal True. idtac "Timing after: summaxlen/slow". Abort. *)

Goal True. idtac "Timing before: summaxlen/symbolic". Abort.
Lemma valid_contract_summaxlen : SMut.ValidContract sep_contract_summaxlen fun_summaxlen.
Proof.
  apply SMut.validcontract_with_erasure_sound.
  hnf.
  compute. constructor.
  compute - [Z.mul Z.add Z.le Z.ge Z.lt].
  solve; nia.
Qed.
Goal True. idtac "Timing after: summaxlen/symbolic". Abort.

Section Debug.

  Goal CMut.ValidContract 1 sep_contract_summaxlen fun_summaxlen.
    compute - [negb Z.mul Z.opp Z.compare Z.add Z.geb Z.eqb Z.leb Z.gtb Z.ltb Z.le Z.lt Z.gt Z.ge].
    change
      (forall xs : list Z, true = true ->
         (nil = xs -> exists (sm : Z * Z) (l : Z), (sm,l) = (0, 0, 0) /\
            (exists s m : Z, (s, m) = sm /\ s <= m * l /\ 0 <= l /\ True)) /\
      (forall (y : Z) (ys : list Z), y :: ys = xs -> exists ys' : list Z, ys' = ys /\ true = true /\
         (forall (sml : Z * Z * Z) (sm : Z * Z) (l : Z), (sm, l) = sml ->
          forall s m : Z, (s, m) = sm -> s <= m * l -> 0 <= l ->
          forall (sm' : Z * Z) (l' : Z), (sm', l') = sml -> forall s' m' : Z, (s',m') = sm' ->
          ((m' <? y) = true -> exists (sm'' : Z * Z) (l'' : Z), (sm'', l'') = (s' + y, y, l' + 1) /\
             (exists s'' m'' : Z, (s'', m'') = sm'' /\ s'' <= m'' * l'' /\ 0 <= l'' /\ True)) /\
          ((m' <? y) = false -> exists (sm'' : Z * Z) (l'' : Z), (sm'', l'') = (s' + y, m', l' + 1) /\
             (exists s'' m'' : Z, (s'', m'') = sm'' /\ s'' <= m'' * l'' /\ 0 <= l'' /\ True)))))%list.
    idtac "Shallow verification condition:".
    match goal with |- ?x => idtac x end.
  Abort.

  Import ty.
  Import SymProp.
  Import SymProp.notations.

  Goal SMut.ValidContract sep_contract_summaxlen fun_summaxlen.
    compute.
    idtac "Symbolic verification condition:".
    match goal with |- VerificationCondition ?x => idtac x end.
  Abort.

  Goal SMut.ValidContract sep_contract_summaxlen fun_summaxlen_with_debug.
    compute.
    idtac "Symbolic verification condition with debug nodes:".
    match goal with |- VerificationCondition ?x => idtac x end.
    idtac "Second debug node:".
    match goal with
    | |- context[SymProp.assumek
                   (formula_ge _ _)
                   (SymProp.debug (MkAMessage _ ?x) _)] =>
        idtac x
    end.
  Abort.

End Debug.

Module ExampleSemantics <: Semantics DefaultBase ExampleProgram :=
  MakeSemantics DefaultBase ExampleProgram.

Module Import ExampleModel.
  Import ExampleProgram.
  Import ExampleSpecification.

  Module ExampleIrisPrelims <: IrisPrelims DefaultBase ExampleProgram ExampleSig ExampleSemantics.
    Include IrisPrelims DefaultBase ExampleProgram ExampleSig ExampleSemantics.
  End ExampleIrisPrelims.

  Module ExampleIrisParameters <: IrisParameters DefaultBase ExampleProgram ExampleSig ExampleSemantics ExampleIrisPrelims.
    Import ExampleIrisPrelims.
    Import iris.bi.interface.
    Import iris.bi.big_op.
    Import iris.base_logic.lib.iprop.
    Import iris.base_logic.lib.gen_heap.
    Import iris.proofmode.tactics.

    Definition memGpreS : gFunctors -> Set := fun Σ => True.
    Definition memGS : gFunctors -> Set := fun Σ => True.
    Definition memΣ : gFunctors := gFunctors.nil.
    Definition memΣ_GpreS : forall {Σ}, subG memΣ Σ -> memGpreS Σ := fun _ _ => I.
    Definition mem_inv : forall {Σ}, memGS Σ -> Memory -> iProp Σ := fun Σ mG μ => True%I.
    Definition mem_res : forall {Σ}, memGS Σ -> Memory -> iProp Σ := fun Σ mG μ => True%I.
    Lemma mem_inv_init : forall Σ (μ : Memory), memGpreS Σ ->
                                                ⊢ |==> ∃ mG : memGS Σ, (mem_inv mG μ ∗ mem_res mG μ)%I.
    Proof.
      now iIntros (Σ μ mG) "".
    Qed.
  End ExampleIrisParameters.

  Module ExampleIrisResources <: IrisResources DefaultBase ExampleSig ExampleSemantics ExampleIrisPrelims ExampleIrisParameters.
    Include IrisResources DefaultBase ExampleSig ExampleSemantics ExampleIrisPrelims ExampleIrisParameters.
  End ExampleIrisResources.

  Module ExampleIrisPredicates <: IrisPredicates DefaultBase ExampleSig ExampleSemantics ExampleIrisPrelims ExampleIrisParameters ExampleIrisResources.
    Import iris.base_logic.lib.iprop.
    Import ExampleIrisPrelims.
    Import ExampleIrisParameters.
      Definition luser_inst : forall `{sRG : sailRegGS Σ} `{wsat.invGS.invGS Σ} (mG : memGS Σ) (p : 𝑯) (ts : Env Val (𝑯_Ty p)), iProp Σ :=
      fun Σ sRG iG mG p ts => match p with end.
      Definition lduplicate_inst : forall `{sRG : sailRegGS Σ} `{wsat.invGS.invGS Σ} (mG : memGS Σ) (p : 𝑯) (ts : Env Val (𝑯_Ty p)),
          is_duplicable p = true -> bi_entails (luser_inst (sRG := sRG) mG _ ts) (luser_inst (sRG := sRG) mG _ ts ∗ luser_inst (sRG := sRG) mG _ ts) :=
        fun Σ sRG iG mG p ts dup => match p with end.
  End ExampleIrisPredicates.

  Import ExampleIrisParameters.

  Include IrisInstance DefaultBase ExampleSig ExampleSemantics ExampleIrisPrelims ExampleIrisParameters ExampleIrisResources ExampleIrisPredicates.
  Include ProgramLogicOn DefaultBase ExampleSig ExampleSpecification.
  Include IrisInstanceWithContracts DefaultBase ExampleSig ExampleSpecification ExampleSemantics ExampleIrisPrelims ExampleIrisParameters ExampleIrisResources ExampleIrisPredicates.

  Import ExampleIrisResources.

  Lemma foreignSem `{sailGS Σ} : ForeignSem.
  Proof. intros Γ τ Δ f es δ; destruct f. Qed.

  Lemma lemSem `{sailGS Σ} : LemmaSem.
  Proof. intros Γ l. destruct l. Qed.

  Include Shallow.Soundness.Soundness DefaultBase ExampleSig ExampleSpecification ExampleShalExec.
  Include Soundness DefaultBase ExampleSig ExampleSpecification ExampleSolver ExampleShalExec ExampleExecutor.

  Section WithIrisNotations.
    Import iris.bi.interface.
    Import iris.base_logic.lib.iprop.
    Import iris.base_logic.lib.iprop.
    Import iris.proofmode.tactics.

    Lemma contracts_sound `{sailGS Σ} : ⊢ ValidContractEnvSem CEnv.
    Proof.
      apply (sound foreignSem lemSem).
      intros Γ τ f c.
      destruct f; inversion 1; subst.
      apply (shallow_execution_soundness 1).
      apply symbolic_execution_soundness.
      apply valid_contract_summaxlen.
    Qed.

    Import ExampleSemantics.SmallStepNotations.

    Definition adequacy_pure_prop (Δ : PCtx) (σ : Ty) (f : Fun Δ σ) : Prop :=
      match CEnv f with
      | Some (MkSepContract _ _ Σ args pre result post) =>
          is_pure pre -> is_pure post ->
          forall Γ (δ δ' : CStore Γ) (γ γ' : RegStore) (μ μ' : Memory) ι,
            interpret_assertion_pure pre ι ->
            forall v,
              (* We could make it more general and allow arbitrary expressions
              as the arguments instead of values. But this is just form
              demonstration purposes. *)
              ⟨ γ, μ, δ, stm_call f (env.map (fun _ => exp_val _) (inst args ι)) ⟩
                --->*
              ⟨ γ', μ', δ', stm_val σ v ⟩  ->
              interpret_assertion_pure post ι.[result∷σ ↦ v]
                (* removed the following: annoying to express in a contract... *)
                (* /\ δ = δ' *)
      | None => True
      end.

    Lemma interpret_assertion_pure_or_not `{sailGS Σ} {Γ} asn (Hasn : is_pure asn) (ι : Valuation Γ) :
      interpret_assertion asn ι ⊣⊢ (⌜ interpret_assertion_pure asn ι ⌝)%I.
    Proof.
      assert (is_pure asn = true) as Hasn' by now apply Is_true_eq_true.
      destruct (interpret_assertion_pure_equiv asn Hasn' ι) as [H1 H2].
      apply bi.equiv_entails_2; auto.
    Qed.

    Lemma adequacy_pure {Δ σ} (f : Fun Δ σ) : adequacy_pure_prop f.
    Proof.
      unfold adequacy_pure_prop.
      remember (CEnv f) as contract.
      destruct contract as [[Σ args pre result post]|]; try now cbn.
      intros preP postP Γ δ δ' γ γ' μ μ' ι PRE v evals.
      refine (SumMaxLen.ExampleModel.adequacy
                (Q := fun v => interpret_assertion_pure post ι.[result∷σ ↦ v]) evals I _).

      iIntros (Σ' sG) "[_ _]".
      iPoseProof (iris_rule_stm_call_forwards δ (f := f) (c := {| sep_contract_logic_variables := Σ; sep_contract_localstore := args; sep_contract_precondition := pre; sep_contract_result := result; sep_contract_postcondition := post |}) (env.map (fun _ => exp_val _) (inst args ι)) (P := interpret_assertion pre ι) (Q := fun v => interpret_assertion post ι.[result::σ ↦ v]) (eq_sym Heqcontract)) as "c".
      - eapply rule_sep_contract.
        + unfold DefaultBase.evals.
          now rewrite env.map_map env.map_id.
        + eapply Logic.sep.lsep_true.
        + cbn. now iIntros (v') "[_ Hpost]".
      - iPoseProof contracts_sound as "Hcontracts".
        iSpecialize ("c" with "Hcontracts").
        unfold semTriple.
        rewrite interpret_assertion_pure_or_not; auto.
        iSpecialize  ("c" $! PRE).
        iApply (weakestpre.wp_mono' with "c").
        iIntros (v') "[Hpost %]".
        now rewrite interpret_assertion_pure_or_not.
    Qed.

    Corollary summaxlen_adequacy {Γ} (δ : CStore Γ) (γ γ' : RegStore) (μ μ' : Memory) :
      forall (xs : list Z) (s m l : Z),
        ⟨ γ, μ, δ, call summaxlen (exp_val (ty.list ty.int) xs) ⟩ --->*
       ⟨ γ', μ', δ, stm_val (ty.prod (ty.prod ty.int ty.int) ty.int) (s, m, l) ⟩ ->
        (s ≤ m * l)%Z /\ (0 ≤ l)%Z.
    Proof.
      intros xs s m l Hsteps.
      generalize (adequacy_pure summaxlen I I Γ δ δ γ γ' μ μ' (env.snoc env.nil _ xs) eq_refl _ Hsteps).
      cbn. intuition.
    Qed.

  End WithIrisNotations.
End ExampleModel.

Goal True. idtac "Assumptions for symbolic_execution_soundness:". Abort.
Print Assumptions symbolic_execution_soundness.
Goal True. idtac "Assumptions for shallow_execution_soundness:". Abort.
Print Assumptions shallow_execution_soundness.
Goal True. idtac "Assumptions for summaxlen_adequacy:". Abort.
Print Assumptions summaxlen_adequacy.

Import SMut.Statistics.
Goal forall {Δ τ} (f : Fun Δ τ),
  calc_statistics f = None.
  idtac "Branching statistics:".
  destruct f; compute;
  match goal with
  | |- Some ?x = None =>
      idtac x
  end.
Abort.
