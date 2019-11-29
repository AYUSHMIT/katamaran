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

From Coq Require Import
     Program.Equality
     Program.Tactics
     Strings.String
     ZArith.ZArith
     micromega.Lia.

From MicroSail Require Import
     WLP.Spec
     Syntax.

Set Implicit Arguments.
Import CtxNotations.
Import EnvNotations.
Open Scope string_scope.
Open Scope Z_scope.
Open Scope ctx_scope.

(*** TYPES ***)

(** Enums **)
Inductive Enums : Set :=
| ordering.

Lemma Enums_eq_dec : forall x y: Enums, {x = y} + {x <> y}.
  decide equality.
Qed.

Inductive Ordering : Set :=
| LT
| EQ
| GT.

(** Unions **)
Inductive Unions : Set :=
.

Lemma Unions_eq_dec : forall x y: Unions, {x = y} + {x <> y}.
  decide equality.
Qed.

(** Records **)
Inductive Records : Set :=
.

Lemma Records_eq_dec : forall x y: Records, {x = y} + {x <> y}.
  decide equality.
Qed.

Module ExampleTypeKit <: TypeKit.

  Definition 𝑬        := Enums.
  Definition 𝑼        := Unions.
  Definition 𝑹        := Records.
  Definition 𝑿        := string.

  Definition 𝑬_eq_dec := Enums_eq_dec.
  Definition 𝑼_eq_dec := Unions_eq_dec.
  Definition 𝑹_eq_dec := Records_eq_dec.
  Definition 𝑿_eq_dec := string_dec.

End ExampleTypeKit.
Module ExampleTypes := Types ExampleTypeKit.
Import ExampleTypes.

(*** TERMS ***)

Module ExampleTermKit <: (TermKit ExampleTypeKit).
  Module TY := ExampleTypes.

  (** ENUMS **)
  Definition 𝑬𝑲 (E : 𝑬) : Set :=
    match E with
    | ordering => Ordering
    end.
  Program Instance Blastable_𝑬𝑲 E : Blastable (𝑬𝑲 E) :=
    match E with
    | ordering => {| blast ord POST :=
                       (ord = LT -> POST LT) /\
                       (ord = EQ -> POST EQ) /\
                       (ord = GT -> POST GT)
                  |}
    end.
  Solve All Obligations with destruct a; intuition congruence.

  (** UNIONS **)
  Definition 𝑼𝑲 (U : 𝑼) : Set := match U with end.
  Definition 𝑼𝑲_Ty (U : 𝑼) : 𝑼𝑲 U -> Ty := match U with end.
  Program Instance Blastable_𝑼𝑲 U : Blastable (𝑼𝑲 U) :=
    match U with
    end.
  Solve All Obligations with destruct a; intuition congruence.

  (** RECORDS **)
  Definition 𝑹𝑭  : Set := Empty_set.
  Definition 𝑹𝑭_Ty (R : 𝑹) : Ctx (𝑹𝑭 * Ty) := match R with end.

  (** FUNCTIONS **)
  Inductive Fun : Ctx (𝑿 * Ty) -> Ty -> Set :=
  | abs :     Fun [ "x" ∶ ty_int               ] ty_int
  | cmp :     Fun [ "x" ∶ ty_int, "y" ∶ ty_int ] (ty_enum ordering)
  | gcd :     Fun [ "x" ∶ ty_int, "y" ∶ ty_int ] ty_int
  | gcdloop : Fun [ "x" ∶ ty_int, "y" ∶ ty_int ] ty_int
  .

  Definition 𝑭  : Ctx (𝑿 * Ty) -> Ty -> Set := Fun.

  Definition 𝑹𝑬𝑮 : Ty -> Set := fun _ => Empty_set.

End ExampleTermKit.
Module ExampleTerms := Terms ExampleTypeKit ExampleTermKit.
Import ExampleTerms.
Import NameResolution.

(*** PROGRAM ***)

Module ExampleProgramKit <: (ProgramKit ExampleTypeKit ExampleTermKit).
  Module TM := ExampleTerms.

  Local Coercion stm_exp : Exp >-> Stm.
  Local Open Scope exp_scope.
  Local Open Scope stm_scope.

  Local Notation "'`LT'" := (exp_lit _ (ty_enum ordering) LT).
  Local Notation "'`GT'" := (exp_lit _ (ty_enum ordering) GT).
  Local Notation "'`EQ'" := (exp_lit _ (ty_enum ordering) EQ).
  Local Notation "'x'"   := (@exp_var _ "x" _ _).
  Local Notation "'y'"   := (@exp_var _ "y" _ _).
  Notation "'call' f a1 .. an" :=
    (stm_call f (env_snoc .. (env_snoc env_nil (_,_) a1) .. (_,_) an))
    (at level 10, f global, a1, an at level 9).

  Definition Pi {Δ τ} (f : Fun Δ τ) : Stm Δ τ.
    let pi := eval compute in
    match f in Fun Δ τ return Stm Δ τ with
    | abs => if: lit_int 0 <= x then x else - x
    | cmp => if: x < y then `LT else
             if: x = y then `EQ else
             if: x > y then `GT else
             fail "cmp failed"
    | gcd => "x" <- call abs x ;;
             "y" <- call abs y ;;
             call gcdloop x y
    | gcdloop =>
             let: "ord" := call cmp x y in
             match: exp_var "ord" in ordering with
             | LT => call gcdloop x (y - x)
             | EQ => x
             | GT => call gcdloop (x - y) y
             end
    end in exact pi.
  Defined.

End ExampleProgramKit.
Import ExampleProgramKit.

(* ⇑ GENERATED                                                                *)
(******************************************************************************)
(* ⇓ NOT GENERATED                                                            *)

Module ExampleContractKit <: (ContractKit ExampleTypeKit ExampleTermKit ExampleProgramKit).

  Definition CEnv : ContractEnv :=
    fun σs τ f =>
      match f with
      | abs        => ContractNoFail
                        ["x" ∶ ty_int] ty_int
                        (fun x γ => True)
                        (fun x r γ => r = Z.abs x)
      | cmp        => ContractNoFail
                        ["x" ∶ ty_int, "y" ∶ ty_int] (ty_enum ordering)
                        (fun x y γ => True)
                        (fun x y r γ =>
                           match r with
                           | LT => x < y
                           | EQ => x = y
                           | GT => x > y
                           end
                           (* (x < y <-> r = LT) /\ *)
                           (* (x = y <-> r = EQ) /\ *)
                           (* (x > y <-> r = GT) *)
                        )
      | gcd        => ContractNoFail
                        ["x" ∶ ty_int, "y" ∶ ty_int] ty_int
                        (fun x y γ => True)
                        (fun x y r γ => r = Z.gcd x y)
      | gcdloop    => ContractNoFail
                        ["x" ∶ ty_int, "y" ∶ ty_int] ty_int
                        (fun x y γ => x >= 0 /\ y >= 0)
                        (fun x y r γ => r = Z.gcd x y)
      end.

End ExampleContractKit.
Import ExampleContractKit.

Module ExampleWLP := WLP ExampleTypeKit ExampleTermKit ExampleProgramKit ExampleContractKit.
Import ExampleWLP.

Lemma gcd_sub_diag_l (n m : Z) : Z.gcd (n - m) m = Z.gcd n m.
Proof. now rewrite Z.gcd_comm, Z.gcd_sub_diag_r, Z.gcd_comm. Qed.

Ltac wlp_cbv :=
  cbv [Blastable_𝑬𝑲 CEnv Forall Lit ValidContract WLP abstract blast
       blastable_lit env_lookup env_map env_update eval evals inctx_case_snoc
       snd uncurry eval_prop_true eval_prop_false
      ].

Ltac validate_solve :=
  repeat
    (intros; subst;
     rewrite ?Z.gcd_diag, ?Z.gcd_abs_l, ?Z.gcd_abs_r, ?Z.gcd_sub_diag_r,
       ?gcd_sub_diag_l;
     intuition (try lia)
    ).

Lemma validCEnv : ValidContractEnv CEnv.
Proof. intros σs τ []; wlp_cbv; validate_solve. Qed.

(* Print Assumptions validCEnv. *)
