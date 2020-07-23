From MicroSail Require Import
     Notation
     Syntax
     Context
     SmallStep.Step
     .

Require Import Coq.Program.Equality.

From iris.program_logic Require Export language ectx_language ectxi_language.
From iris.program_logic Require Export weakestpre.

Set Implicit Arguments.

Module IrisInstance
       (Import typekit : TypeKit)
       (Import termkit : TermKit typekit)
       (Import progkit : ProgramKit typekit termkit).

  Import CtxNotations.
  Import EnvNotations.

  Definition σt : Ty := ty_bool.

  Module SS := SmallStep typekit termkit progkit.
  Import SS.

  Inductive Tm : Type :=
  | MkTm {Γ : Ctx (𝑿 * Ty)} (δ : LocalStore Γ) (s : Stm Γ σt) : Tm.

  Inductive Val : Type :=
  | MkVal (v : Lit σt) : Val.

  Definition of_val (v : Val) : Tm :=
    match v with
      MkVal v => MkTm env_nil (stm_lit _ v)
    end.

  Definition observation := Empty_set.

  Definition State := prod RegStore Memory.

  Inductive prim_step : Tm -> State -> Tm -> State -> Prop :=
  | mk_prim_step {Γ  Γ : Ctx (𝑿 * Ty)} γ1 γ2 μ1 μ2 (δ1 : LocalStore Γ) (δ2 : LocalStore Γ) s1 s2 :
      Step γ1 γ2 μ1 μ2 δ1 δ2 s1 s2 ->
      prim_step (MkTm δ1 s1) (γ1 , μ1) (MkTm δ2 s2) (γ2 , μ2)
  .

  Definition to_val (t : Tm) : option Val :=
    (* easier way to do the dependent pattern match here? *)
    match t with
    | MkTm δ s => (match s in Stm _ σ return σ = σt -> option Val with
                   stm_lit τ l => fun eq => Some (MkVal (eq_rect _ Lit l _ eq))
                 | _ => fun _ => None
                 end) eq_refl
    end.

  Lemma to_of_val v : to_val (of_val v) = Some v.
  Proof.
    by induction v.
  Qed.

  Lemma of_to_val e v : to_val e = Some v → of_val v = e.
  Proof.
    (* sigh... no dependent pattern matching *)
  Admitted.

  Lemma val_head_stuck e1 s1 e2 s2 : prim_step e1 s1 e2 s2 → to_val e1 = None.
  Proof.
  Admitted.

  Lemma lang_mixin : @LanguageMixin _ _ State Empty_set of_val to_val (fun e1 s1 ls e2 s2 ks => prim_step e1 s1 e2 s2).
  Proof.
    split; apply _ || eauto using to_of_val, of_to_val, val_head_stuck.
  Qed.

  Canonical Structure stateO := leibnizO State.
  Canonical Structure valO := leibnizO Val.
  Canonical Structure exprO := leibnizO Tm.

  Context `{invG Σ}.

  Canonical Structure lang : language := Language lang_mixin.

  Definition test : iProp Σ := WP (MkTm env_nil (stm_lit ty_bool true)) {{ v, True }}%I.

End IrisInstance.
