(******************************************************************************)
(* Copyright (c) 2020 Steven Keuchel                                          *)
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
     Lists.List
     Logic.EqdepFacts
     Program.Equality
     Program.Tactics
     Strings.String
     Arith.PeanoNat
     ZArith.ZArith.

From Equations Require Import Equations.

From MicroSail Require Import
     Sep.Spec
     SemiConcrete.Outcome
     Syntax.

From stdpp Require Import base list option.

Import CtxNotations.
Import EnvNotations.
Import ListNotations.
Import OutcomeNotations.

Set Implicit Arguments.

Delimit Scope mutator_scope with mut.
Delimit Scope dmut_scope with dmut.

Module SemiConcrete
       (termkit : TermKit)
       (progkit : ProgramKit termkit)
       (assertkit : AssertionKit termkit progkit)
       (symcontractkit : SymbolicContractKit termkit progkit assertkit).

  Export symcontractkit.

  Section SemiConcreteState.

    Local Set Primitive Projections.

    Record SCState (Γ : PCtx) : Type :=
      MkSCState
        { scstate_localstore    : LocalStore Γ;
          scstate_heap          : SCHeap;
        }.
    Global Arguments scstate_localstore {_} _.
    Global Arguments scstate_heap {_} _.

    Definition scstate_initial {Γ} (δ : LocalStore Γ) : SCState Γ :=
      MkSCState δ nil.

    Definition scstate_produce_chunk {Γ} (c : SCChunk) : SCState Γ -> SCState Γ :=
      fun '(MkSCState δ h) => MkSCState δ (cons c h).

  End SemiConcreteState.

  Section ChunkExtraction.

    Equations(noeqns) match_chunk_eqb (ce : SCChunk) (cr : SCChunk) : bool :=
      match_chunk_eqb (scchunk_user p1 vs1) (scchunk_user p2 vs2)
      with eq_dec p1 p2 => {
        match_chunk_eqb (scchunk_user p1 vs1) (scchunk_user p2 vs2) (left eq_refl) := env_eqb_hom Lit_eqb vs1 vs2;
        match_chunk_eqb (scchunk_user p1 vs1) (scchunk_user p2 vs2) (right _) := false
      };
      match_chunk_eqb (scchunk_ptsreg r1 t1) (scchunk_ptsreg r2 t2)
      with eq_dec_het r1 r2 => {
        match_chunk_eqb (scchunk_ptsreg r1 v1) (scchunk_ptsreg r2 v2) (left eq_refl) := Lit_eqb _ v1 v2;
        match_chunk_eqb (scchunk_ptsreg r1 v1) (scchunk_ptsreg r2 v2) (right _)      := false
      };
      match_chunk_eqb _ _  := false.

    Local Set Equations With UIP.
    Lemma match_chunk_eqb_spec (c1 c2 : SCChunk) :
      reflect (c1 = c2) (match_chunk_eqb c1 c2).
    Proof.
      destruct c1 as [p1 vs1|r1], c2 as [p2 vs2|r2]; cbn.
      - destruct (eq_dec p1 p2); cbn.
        + dependent elimination e; cbn.
          destruct (env_eqb_hom_spec _ Lit_eqb_spec vs1 vs2); constructor.
          * congruence.
          * intros e. now dependent elimination e.
        + constructor; intro e.
          now dependent elimination e.
      - constructor. discriminate.
      - constructor. discriminate.
      - destruct (eq_dec_het r r0); cbn.
        + dependent elimination e; cbn.
          apply (ssrbool.iffP (Lit_eqb_spec _ _ _));
            intro e; now dependent elimination e.
        + constructor.
          intro e; now dependent elimination e.
    Qed.

    Definition extract_chunk_eqb (ce : SCChunk) (h : SCHeap) : list SCHeap :=
      List.map snd (List.filter (fun '(cr,_) => match_chunk_eqb ce cr) (heap_extractions h)).

  End ChunkExtraction.

  Section SemiConcreteMutatorResult.

    Local Set Primitive Projections.
    Local Set Maximal Implicit Insertion.

    Record SCMutResult (Γ : PCtx) (A : Type) : Type :=
      MkSCMutResult {
          scmutres_value : A;
          scmutres_state : SCState Γ;
        }.

  End SemiConcreteMutatorResult.

  Section SemiConcreteMutator.

    Definition SCMut (Γ1 Γ2 : PCtx) (A : Type) : Type :=
      SCState Γ1 -> Outcome (SCMutResult Γ2 A).
    Bind Scope mutator_scope with SCMut.

    Definition scmut_demonic {Γ1 Γ2 I A} (ms : I -> SCMut Γ1 Γ2 A) : SCMut Γ1 Γ2 A :=
      fun (s : SCState Γ1) => (⨂ i : I => ms i s)%out.
    Definition scmut_angelic {Γ1 Γ2 I A} (ms : I -> SCMut Γ1 Γ2 A) : SCMut Γ1 Γ2 A :=
      fun (s : SCState Γ1) => (⨁ i : I => ms i s)%out.
    Definition scmut_fail {Γ1 Γ2 A} (msg : string) : SCMut Γ1 Γ2 A :=
      fun s => outcome_fail msg.
    Definition scmut_block {Γ1 Γ2 A} : SCMut Γ1 Γ2 A :=
      fun s => outcome_block.

    Definition scmut_demonic_binary {Γ1 Γ2 A} (m1 m2 : SCMut Γ1 Γ2 A) : SCMut Γ1 Γ2 A :=
      fun s => outcome_demonic_binary (m1 s) (m2 s).
    Definition scmut_angelic_binary {Γ1 Γ2 A} (m1 m2 : SCMut Γ1 Γ2 A) : SCMut Γ1 Γ2 A :=
      fun s => outcome_angelic_binary (m1 s) (m2 s).

    Definition scmut_pure {Γ A} (a : A) : SCMut Γ Γ A :=
      fun s => outcome_pure (MkSCMutResult a s).
    Definition scmut_bind {Γ1 Γ2 Γ3 A B} (ma : SCMut Γ1 Γ2 A) (f : A -> SCMut Γ2 Γ3 B) : SCMut Γ1 Γ3 B :=
      fun s0 => outcome_bind (ma s0) (fun '(MkSCMutResult a s1) => f a s1).
    Definition scmut_bind_right {Γ1 Γ2 Γ3 A B} (ma : SCMut Γ1 Γ2 A) (mb : SCMut Γ2 Γ3 B) : SCMut Γ1 Γ3 B :=
      scmut_bind ma (fun _ => mb).
    Definition scmut_bind_left {Γ1 Γ2 Γ3 A B} (ma : SCMut Γ1 Γ2 A) (mb : SCMut Γ2 Γ3 B) : SCMut Γ1 Γ3 A :=
      scmut_bind ma (fun a => scmut_bind mb (fun _ => scmut_pure a)).
    Definition scmut_map {Γ1 Γ2 A B} (f : A -> B) (ma : SCMut Γ1 Γ2 A) : SCMut Γ1 Γ2 B :=
      scmut_bind ma (fun a => scmut_pure (f a)).
    Definition scmut_angelick_list {Γ1 Γ2 A B} (msg : string) (xs : list A) (k : A -> SCMut Γ1 Γ2 B) : SCMut Γ1 Γ2 B :=
      fun s => outcome_angelick_list msg xs (fun a => k a s).

  End SemiConcreteMutator.
  Bind Scope mutator_scope with SCMut.

  Module MutatorNotations.

    Notation "'⨂' x .. y => F" :=
      (scmut_demonic (fun x => .. (scmut_demonic (fun y => F)) .. )) : mutator_scope.

    Notation "'⨁' x .. y => F" :=
      (scmut_angelic (fun x => .. (scmut_angelic (fun y => F)) .. )) : mutator_scope.

    Infix "⊗" := scmut_demonic_binary (at level 40, left associativity) : mutator_scope.
    Infix "⊕" := scmut_angelic_binary (at level 50, left associativity) : mutator_scope.

    Notation "x <- ma ;; mb" :=
      (scmut_bind ma (fun x => mb))
        (at level 80, ma at level 90, mb at level 200, right associativity) : mutator_scope.
    Notation "ma >>= f" := (scmut_bind ma f) (at level 50, left associativity) : mutator_scope.
    Notation "m1 ;; m2" := (scmut_bind_right m1 m2) : mutator_scope.
    Notation "ma *> mb" := (scmut_bind_right ma mb) (at level 50, left associativity) : mutator_scope.
    Notation "ma <* mb" := (scmut_bind_left ma mb) (at level 50, left associativity) : mutator_scope.

  End MutatorNotations.
  Import MutatorNotations.

  Section MutatorOperations.

    Local Open Scope mutator_scope.

    Definition scmut_state {Γ Γ' A} (f : SCState Γ -> (A * SCState Γ')) : SCMut Γ Γ' A :=
      fun s => outcome_pure (let (a,s1) := f s in MkSCMutResult a s1).
    Definition scmut_modify {Γ Γ'} (f : SCState Γ -> SCState Γ') : SCMut Γ Γ' unit :=
      scmut_state (fun s => (tt,f s)).
    Definition scmut_put {Γ Γ'} (s : SCState Γ') : SCMut Γ Γ' unit :=
      scmut_state (fun _ => (tt,s)).
    Definition scmut_get {Γ} : SCMut Γ Γ (SCState Γ) :=
      scmut_state (fun s => (s,s)).

    Definition scmut_state_local {Γ Γ' A} (f : LocalStore Γ -> (LocalStore Γ' * A)) : SCMut Γ Γ' A :=
      scmut_state (fun '(MkSCState δ ĥ) => let (δ',a) := f δ in (a,MkSCState δ' ĥ)).
    Definition scmut_modify_local {Γ Γ'} (f : LocalStore Γ -> LocalStore Γ') : SCMut Γ Γ' unit :=
      scmut_state_local (fun δ => (f δ,tt)).
    Definition scmut_put_local {Γ Γ'} (δ : LocalStore Γ') : SCMut Γ Γ' unit :=
      scmut_state_local (fun _ => (δ,tt)).
    Definition scmut_get_local {Γ} : SCMut Γ Γ (LocalStore Γ) :=
      scmut_state_local (fun δ => (δ,δ)).
    Definition scmut_gets_local {Γ A} (f : LocalStore Γ -> A) : SCMut Γ Γ A :=
      scmut_state_local (fun δ => (δ,f δ)).
    Definition scmut_pop_local {Γ x σ} : SCMut (Γ ▻ (x :: σ)) Γ unit :=
      scmut_modify_local (fun δ => env_tail δ).
    Definition scmut_pops_local {Γ} Δ : SCMut (Γ ▻▻ Δ) Γ unit :=
      scmut_modify_local (fun δΓΔ => env_drop Δ δΓΔ).
    Definition scmut_push_local {Γ x σ} (v : Lit σ) : SCMut Γ (Γ ▻ (x :: σ)) unit :=
      scmut_modify_local (fun δ => env_snoc δ (x :: σ) v).
    Definition scmut_pushs_local {Γ Δ} (δΔ : LocalStore Δ) : SCMut Γ (Γ ▻▻ Δ) unit :=
      scmut_modify_local (fun δΓ => env_cat δΓ δΔ).

    Definition scmut_pushpop {A} {Γ1 Γ2 x σ} (v : Lit σ) (d : SCMut (Γ1 ▻ (x :: σ)) (Γ2 ▻ (x :: σ)) A) :
      SCMut Γ1 Γ2 A :=
      scmut_push_local v ;; scmut_bind_left d scmut_pop_local.
    Definition scmut_pushspops {A} {Γ1 Γ2 Δ} (δΔ : LocalStore Δ) (d : SCMut (Γ1 ▻▻ Δ) (Γ2 ▻▻ Δ) A) :
      SCMut Γ1 Γ2 A :=
      scmut_pushs_local δΔ ;; scmut_bind_left d (scmut_pops_local Δ).

    Definition scmut_state_heap {Γ A} (f : SCHeap -> (SCHeap * A)) : SCMut Γ Γ A :=
      scmut_state (fun '(MkSCState δ h) => let (h',a) := f h in (a,MkSCState δ h')).
    Definition scmut_modify_heap {Γ} (f : SCHeap -> SCHeap) : SCMut Γ Γ unit :=
      scmut_state_heap (fun h => (f h,tt)).
    Definition scmut_get_heap {Γ} : SCMut Γ Γ SCHeap :=
      scmut_state_heap (fun h => (h,h)).
    Definition scmut_put_heap {Γ} (h : SCHeap) : SCMut Γ Γ unit :=
      scmut_state_heap (fun _ => (h,tt)).

    Definition scmut_eval_exp {Γ σ} (e : Exp Γ σ) : SCMut Γ Γ (Lit σ) :=
      scmut_gets_local (fun δ => eval e δ).
    Definition scmut_eval_exps {Γ} {σs : PCtx} (es : NamedEnv (Exp Γ) σs) : SCMut Γ Γ (LocalStore σs) :=
      scmut_gets_local (fun δ => env_map (fun _ e => eval e δ) es).

    Definition scmut_produce_chunk {Γ} (c : SCChunk) : SCMut Γ Γ unit :=
      scmut_modify (scstate_produce_chunk c).
    Definition scmut_consume_chunk {Γ} (c : SCChunk) : SCMut Γ Γ unit :=
      scmut_get_heap >>= fun h =>
        scmut_angelick_list
        "Err [scmut_consume_chunk]: empty extraction"
        (extract_chunk_eqb c h)
        scmut_put_heap.
    Global Arguments scmut_push_local {Γ _ _} _.
    Global Arguments scmut_produce_chunk {Γ} _.
    Global Arguments scmut_consume_chunk {Γ} _.

    Local Opaque instantiate_env.
    Local Opaque instantiate_term.

    Definition scmut_assume_formula {Γ Σ} (ι : SymInstance Σ) (fml : Formula Σ) : SCMut Γ Γ unit :=
      fun s => outcome_assumek
                 (inst ι fml)
                 (outcome_pure {| scmutres_value := tt; scmutres_state := s |}).
    Definition scmut_assume_term {Γ Σ} (ι : SymInstance Σ) (t : Term Σ ty_bool) : SCMut Γ Γ unit :=
      scmut_assume_formula ι (formula_bool t).
    Definition scmut_assert_formula {Γ Σ} (ι : SymInstance Σ) (fml : Formula Σ) : SCMut Γ Γ unit :=
      fun s => outcome_assertk
                 (inst ι fml)
                 (outcome_pure {| scmutres_value := tt; scmutres_state := s |}).

    Definition scmut_match_sum {A} {Γ1 Γ2 σ τ} (v : Lit σ + Lit τ)
      (sinl : Lit σ -> SCMut Γ1 Γ2 A) (sinr : Lit τ -> SCMut Γ1 Γ2 A) : SCMut Γ1 Γ2 A :=
      match v with
      | inl v => sinl v
      | inr v => sinr v
      end.

    Definition scmut_match_pair {A} {Γ1 Γ2 σ τ} (v : Lit σ * Lit τ)
      (m : Lit σ -> Lit τ -> SCMut Γ1 Γ2 A) : SCMut Γ1 Γ2 A :=
      match v with (vl,vr) => m vl vr end.

    Definition scmut_match_enum {A E} {Γ1 Γ2} (v : 𝑬𝑲 E)
      (m : 𝑬𝑲 E -> SCMut Γ1 Γ2 A) : SCMut Γ1 Γ2 A :=
      m v.

    Definition scmut_match_record {A R} {Γ1 Γ2 Δ} (p : RecordPat (𝑹𝑭_Ty R) Δ) (t : Lit (ty_record R))
      (m : SymInstance Δ -> SCMut Γ1 Γ2 A) : SCMut Γ1 Γ2 A :=
      m (record_pattern_match p (𝑹_unfold t)).

    Fixpoint scmut_produce {Γ Σ} (ι : SymInstance Σ) (asn : Assertion Σ) : SCMut Γ Γ unit :=
      match asn with
      | asn_formula fml => scmut_assume_formula ι fml
      | asn_chunk c     => scmut_produce_chunk (inst ι c)
      | asn_if b a1 a2  => (scmut_assume_term ι b ;; scmut_produce ι a1) ⊗
                           (scmut_assume_term ι (term_not b) ;; scmut_produce ι a2)
      | asn_match_enum E k alts =>
        scmut_match_enum
          (inst (T := fun Σ => Term Σ _) ι k)
          (fun K => scmut_produce ι (alts K))
      | asn_match_sum σ τ s xl alt_inl xr alt_inr =>
        scmut_match_sum
          (inst (T := fun Σ => Term Σ _) ι s)
          (fun v => scmut_produce (env_snoc ι (xl :: σ) v) alt_inl)
          (fun v => scmut_produce (env_snoc ι (xr :: τ) v) alt_inr)
      | asn_match_list s alt_nil xh xt alt_cons =>
        match inst (T := fun Σ => Term Σ _) ι s with
        | nil        => scmut_produce ι alt_nil
        | cons vh vt => scmut_produce (ι ► (xh :: _ ↦ vh) ► (xt :: ty_list _ ↦ vt)) alt_cons
        end
      | asn_match_pair s xl xr rhs =>
        scmut_match_pair
          (inst (T := fun Σ => Term Σ _) ι s)
          (fun vl vr => scmut_produce (ι ► (xl :: _ ↦ vl) ► (xr :: _ ↦ vr)) rhs)
      | asn_match_tuple s p rhs =>
        let t := inst (T := fun Σ => Term Σ _) ι s in
        let ι' := tuple_pattern_match p t in
        scmut_produce (ι ►► ι') rhs
      | asn_match_record R s p rhs =>
        scmut_match_record p
          (inst (T := fun Σ => Term Σ _) ι s)
          (fun ι' => scmut_produce (ι ►► ι') rhs)
      | asn_match_union U s alt__ctx alt__pat alt__rhs =>
        let t := inst (T := fun Σ => Term Σ _) ι s in
        let (K , v) := 𝑼_unfold t in
        let ι' := pattern_match (alt__pat K) v in
        scmut_produce (ι ►► ι') (alt__rhs K)
      | asn_sep a1 a2   => scmut_produce ι a1 *> scmut_produce ι a2
      | asn_exist ς τ a => ⨂ v : Lit τ => scmut_produce (env_snoc ι (ς :: τ) v) a
      | asn_debug => scmut_pure tt
      end.

    Fixpoint scmut_consume {Γ Σ} (ι : SymInstance Σ) (asn : Assertion Σ) : SCMut Γ Γ unit :=
      match asn with
      | asn_formula fml => scmut_assert_formula ι fml
      | asn_chunk c     => scmut_consume_chunk (inst ι c)
      | asn_if b a1 a2  => (scmut_assume_term ι b ;; scmut_consume ι a1) ⊗
                           (scmut_assume_term ι (term_not b) ;; scmut_consume ι a2)
      | asn_match_enum E k alts =>
        scmut_match_enum
          (inst (T := fun Σ => Term Σ _) ι k)
          (fun K => scmut_consume ι (alts K))
      | asn_match_sum σ τ s xl alt_inl xr alt_inr =>
        scmut_match_sum
          (inst (T := fun Σ => Term Σ _) ι s)
          (fun v => scmut_consume (env_snoc ι (xl :: σ) v) alt_inl)
          (fun v => scmut_consume (env_snoc ι (xr :: τ) v) alt_inr)
      | asn_match_list s alt_nil xh xt alt_cons =>
        match inst (T := fun Σ => Term Σ _) ι s with
        | nil        => scmut_consume ι alt_nil
        | cons vh vt => scmut_consume (ι ► (xh :: _ ↦ vh) ► (xt :: ty_list _ ↦ vt)) alt_cons
        end
      | asn_match_pair s xl xr rhs =>
        scmut_match_pair
          (inst (T := fun Σ => Term Σ _) ι s)
          (fun vl vr => scmut_consume (ι ► (xl :: _ ↦ vl) ► (xr :: _ ↦ vr)) rhs)
      | asn_match_tuple s p rhs =>
        let t := inst (T := fun Σ => Term Σ _) ι s in
        let ι' := tuple_pattern_match p t in
        scmut_consume (ι ►► ι') rhs
      | asn_match_record R s p rhs =>
        scmut_match_record p
          (inst (T := fun Σ => Term Σ _) ι s)
          (fun ι' => scmut_consume (ι ►► ι') rhs)
      | asn_match_union U s alt__ctx alt__pat alt__rhs =>
        let t := inst (T := fun Σ => Term Σ _) ι s in
        let (K , v) := 𝑼_unfold t in
        let ι' := pattern_match (alt__pat K) v in
        scmut_consume (ι ►► ι') (alt__rhs K)
      | asn_sep a1 a2   => scmut_consume ι a1 *> scmut_consume ι a2
      | asn_exist ς τ a => ⨁ v : Lit τ => scmut_consume (env_snoc ι (ς :: τ) v) a
      | asn_debug => scmut_pure tt
      end.

    Definition scmut_call {Γ Δ τ} (contract : SepContract Δ τ) (vs : LocalStore Δ) : SCMut Γ Γ (Lit τ) :=
      match contract with
      | MkSepContract _ _ Σe δ req result ens =>
        ⨁ ι : SymInstance Σe =>
        ⨁ H : vs = inst ι δ =>
        scmut_consume ι req  ;;
        ⨂ v : Lit τ =>
        scmut_produce (env_snoc ι (result::τ) v) ens ;;
        scmut_pure v
      end.

    Fixpoint scmut_exec {Γ τ} (s : Stm Γ τ) : SCMut Γ Γ (Lit τ) :=
      match s with
      | stm_lit _ l => scmut_pure l
      | stm_exp e => scmut_eval_exp e
      | stm_let x σ s k =>
        v <- scmut_exec s ;;
        scmut_pushpop v (scmut_exec k)
      | stm_block δ k =>
        scmut_pushspops δ (scmut_exec k)
      | stm_assign x e =>
        v <- scmut_exec e ;;
        scmut_modify_local (fun δ => δ ⟪ x ↦ v ⟫)%env ;;
        scmut_pure v
      | stm_call f es =>
        match CEnv f with
        | Some c => scmut_eval_exps es >>= scmut_call c
        | None   => scmut_fail "Err [scmut_exec]: Function call without contract"
        end
      | stm_call_external f es => scmut_eval_exps es >>= scmut_call (CEnvEx f)
      | stm_call_frame δ' s =>
        δ <- scmut_get_local ;;
        scmut_put_local δ' ;;
        v <- scmut_exec s ;;
        scmut_put_local δ ;;
        scmut_pure v
      | stm_if e s1 s2 =>
        v <- scmut_eval_exp e ;;
        if v
        then scmut_exec s1
        else scmut_exec s2
      | stm_seq e k => scmut_exec e ;; scmut_exec k
      | stm_assertk e1 _ k =>
        v <- scmut_eval_exp e1 ;;
        if v
        then scmut_exec k
        else scmut_block
      | stm_fail _ s =>
        scmut_block
      | stm_match_enum E e alts =>
        K <- scmut_eval_exp e ;;
        scmut_match_enum
          K
          (fun K => scmut_exec (alts K))
      | stm_read_register reg =>
        ⨁ v : Lit τ =>
        let c := scchunk_ptsreg reg v in
        scmut_consume_chunk c ;;
        scmut_produce_chunk c ;;
        scmut_pure v
      | stm_write_register reg e =>
        v__new <- scmut_eval_exp e ;;
        ⨁ v__old : Lit τ =>
        scmut_consume_chunk (scchunk_ptsreg reg v__old) ;;
        scmut_produce_chunk (scchunk_ptsreg reg v__new) ;;
        scmut_pure v__new
      | @stm_match_list _ _ σ e s1 xh xt s2 =>
        v <- scmut_eval_exp e ;;
        match v : list (Lit σ) with
        | nil => scmut_exec s1
        | cons h t =>
          scmut_pushspops
            (env_snoc (env_snoc env_nil (xh :: σ) h) (xt :: ty_list σ) t)
            (scmut_exec s2)
        end
      | stm_match_sum e xinl s1 xinr s2 =>
        v <- scmut_eval_exp e ;;
        scmut_match_sum
          v
          (fun v => scmut_pushpop v (scmut_exec s1))
          (fun v => scmut_pushpop v (scmut_exec s2))
      | stm_match_pair e xl xr s =>
        v <- scmut_eval_exp e ;;
        scmut_match_pair
          v
          (fun vl vr =>
             scmut_pushspops
               (env_snoc (env_snoc env_nil (xl :: _) vl) (xr :: _) vr)
               (scmut_exec s))
      | stm_match_tuple e p rhs =>
        v <- scmut_eval_exp e ;;
        scmut_pushs_local (tuple_pattern_match p v) ;;
        scmut_exec rhs <*
        scmut_pops_local _
      | stm_match_union U e alt__pat alt__rhs =>
        v <- scmut_eval_exp e ;;
        let (K , v) := 𝑼_unfold v in
        scmut_pushspops (pattern_match (alt__pat K) v) (scmut_exec (alt__rhs K))
      | stm_match_record R e p rhs =>
        v <- scmut_eval_exp e ;;
        scmut_pushspops (record_pattern_match p (𝑹_unfold v)) (scmut_exec rhs)
      | stm_bind s k =>
        v <- scmut_exec s ;;
        scmut_exec (k v)
      | stm_debugk k =>
        scmut_exec k
      end.

    Definition scmut_leakcheck {Γ} : SCMut Γ Γ unit :=
      scmut_get_heap >>= fun h =>
      match h with
      | nil => scmut_pure tt
      | _   => scmut_fail "Err [scmut_leakcheck]: heap leak"
      end.

  End MutatorOperations.

  Import OutcomeNotations.

  Section SemiConcreteWP.

    Definition scmut_wp {Γ1 Γ2 A}
      (m : SCMut Γ1 Γ2 A)
      (POST : A -> SCState Γ2 -> Prop)
      (s1 : SCState Γ1) : Prop :=
      outcome_satisfy (m s1) (fun r => POST (scmutres_value r) (scmutres_state r)).

    Lemma scmut_wp_monotonic {A} {Γ1 Γ2} (m : SCMut Γ1 Γ2 A) (s1 : SCState Γ1)
      (P Q : A -> SCState Γ2 -> Prop) (PQ : forall a s, P a s -> Q a s) :
      scmut_wp m P s1 -> scmut_wp m Q s1.
    Proof. unfold scmut_wp. apply outcome_satisfy_monotonic; intros []; apply PQ. Qed.

    Lemma scmut_wp_equiv {A} {Γ1 Γ2} (m : SCMut Γ1 Γ2 A) (s1 : SCState Γ1)
      (P Q : A -> SCState Γ2 -> Prop) (PQ : forall a s, P a s <-> Q a s) :
        scmut_wp m P s1 <-> scmut_wp m Q s1.
    Proof. split; apply scmut_wp_monotonic; apply PQ. Qed.

    Lemma scmut_wp_bind {Γ1 Γ2 Γ3 A B} (ma : SCMut Γ1 Γ2 A) (f : A -> SCMut Γ2 Γ3 B)
          (POST : B -> SCState Γ3 -> Prop) :
      forall s1 : SCState Γ1,
        scmut_wp (scmut_bind ma f) POST s1 <->
        scmut_wp ma (fun a => scmut_wp (f a) POST) s1.
    Proof.
      unfold SCMut, scmut_bind, scmut_wp in *; cbn; intros.
      now rewrite outcome_satisfy_bind.
    Qed.

    Lemma scmut_wp_demonic {Γ1 Γ2 A B} (sm : B -> SCMut Γ1 Γ2 A) (s__sc : SCState Γ1) (POST : A -> SCState Γ2 -> Prop) :
      scmut_wp (scmut_demonic sm) POST s__sc <-> forall v, scmut_wp (sm v) POST s__sc.
    Proof. unfold scmut_wp, scmut_demonic; cbn; intuition. Qed.

    Lemma scmut_wp_demonic_binary {Γ1 Γ2 A} (sm1 sm2 : SCMut Γ1 Γ2 A) (s__sc : SCState Γ1) (POST : A -> SCState Γ2 -> Prop) :
      scmut_wp (scmut_demonic_binary sm1 sm2) POST s__sc <->
      scmut_wp sm1 POST s__sc /\ scmut_wp sm2 POST s__sc.
    Proof. unfold scmut_wp, scmut_demonic_binary; cbn; intuition. Qed.

    Lemma scmut_wp_angelic {Γ1 Γ2 A B} (sm : B -> SCMut Γ1 Γ2 A) (s__sc : SCState Γ1) (POST : A -> SCState Γ2 -> Prop) :
      scmut_wp (scmut_angelic sm) POST s__sc <-> exists v, scmut_wp (sm v) POST s__sc.
    Proof. unfold scmut_wp, scmut_angelic; cbn; intuition. Qed.

    Lemma scmut_wp_angelic_binary {Γ1 Γ2 A} (sm1 sm2 : SCMut Γ1 Γ2 A) (s__sc : SCState Γ1) (POST : A -> SCState Γ2 -> Prop) :
      scmut_wp (scmut_angelic_binary sm1 sm2) POST s__sc <->
      scmut_wp sm1 POST s__sc \/ scmut_wp sm2 POST s__sc.
    Proof. unfold scmut_wp, scmut_angelic_binary; cbn; intuition. Qed.

    Lemma scmut_wp_state {Γ1 Γ2 A} (f : SCState Γ1 -> A * SCState Γ2) (POST : A -> SCState Γ2 -> Prop) :
      forall (s1 : SCState Γ1),
        scmut_wp (scmut_state f) POST s1 <-> POST (fst (f s1)) (snd (f s1)).
    Proof. intros s1. cbn. now destruct (f s1); cbn. Qed.

  End SemiConcreteWP.

  Definition scmut_contract {Δ τ} (c : SepContract Δ τ) (s : Stm Δ τ) :
   SymInstance (sep_contract_logic_variables c) -> SCMut Δ Δ unit :=
    match c with
    | MkSepContract _ _ Σ δ req result ens =>
      fun ι =>
      scmut_produce ι req ;;
      scmut_exec s >>= fun v =>
      scmut_consume (env_snoc ι (result::τ) v) ens ;;
      scmut_leakcheck
    end%mut.

  Definition semiconcrete_outcome_contract {Δ : PCtx} {τ : Ty} (c : SepContract Δ τ) (s : Stm Δ τ) :
    Outcome unit :=
      ⨂ ι : SymInstance (sep_contract_logic_variables c) =>
      let δΔ : LocalStore Δ := inst ι (sep_contract_localstore c) in
      let mut := scmut_contract c s ι in
      let out := mut (scstate_initial δΔ) in
      outcome_map (fun _ => tt) out.

  Definition ValidContractSCMut {Δ τ} (c : SepContract Δ τ) (body : Stm Δ τ) : Prop :=
    outcome_satisfy (semiconcrete_outcome_contract c body) (fun _ => True).

End SemiConcrete.
