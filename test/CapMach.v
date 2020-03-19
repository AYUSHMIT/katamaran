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
     Program.Tactics
     Strings.String
     ZArith.ZArith.

From Equations Require Import
     Equations.

From MicroSail Require Import
     Sep.Spec
     Syntax.

Set Implicit Arguments.
Import CtxNotations.
Import EnvNotations.
Open Scope string_scope.
Open Scope Z_scope.
Open Scope ctx_scope.

(*** TYPES ***)

Inductive Permission : Set :=
  O | E | R | RX | RW | RWX.

Inductive RegName : Set :=
  R0 | R1 | R2 | R3.

Definition LV : Set := RegName.
Definition HV : Set := RegName.
Definition RV : Set := LV + Z.

Inductive Instruction : Set :=
| jmp      (lv : LV)
| jnz      (lv : LV) (rv : RV)
| move     (lv : LV) (rv : RV)
| load     (lv : LV) (hv : HV)
| store    (hv : HV) (rv : RV)
| lt       (lv : LV) (rv1 rv2 : RV)
| plus     (lv : LV) (rv1 rv2 : RV)
| minus    (lv : LV) (rv1 rv2 : RV)
| lea      (lv : LV) (rv : RV)
| restrict (lv : LV) (rv : RV)
| subseg   (lv : LV) (rv1 rv2 : RV)
| isptr    (lv : LV) (rv : RV)
| getp     (lv lv' : LV)
| getb     (lv lv' : LV)
| gete     (lv lv' : LV)
| geta     (lv lv' : LV)
| fail
| halt.

Inductive InstructionConstructor : Set :=
| kjmp
| kjnz
| kmove
| kload
| kstore
| klt
| kplus
| kminus
| klea
| krestrict
| ksubseg
| kisptr
| kgetp
| kgetb
| kgete
| kgeta
| kfail
| khalt.

Section Records.
  Local Set Primitive Projections.

  Record Addr : Set :=
    MkAddr
      { addr_int : Z;
      }.

  Record Capability : Set :=
    MkCap
      { cap_permission : Permission;
        cap_begin      : Addr;
        cap_end        : option Addr;
        cap_cursor     : Addr;
      }.

End Records.

(** Enums **)
Inductive Enums : Set :=
| permission
| regname.

(** Unions **)
Inductive Unions : Set :=
| instruction.

(** Records **)
Inductive Records : Set :=
| addr
| capability.

Section TransparentObligations.
  Local Set Transparent Obligations.

  Derive NoConfusion for Addr.
  Derive NoConfusion for Capability.
  Derive NoConfusion for Permission.
  Derive NoConfusion for RegName.
  Derive NoConfusion for Enums.
  Derive NoConfusion for Unions.
  Derive NoConfusion for Records.
  Derive NoConfusion for Instruction.
  Derive NoConfusion for InstructionConstructor.

End TransparentObligations.

Derive EqDec for Addr.
Derive EqDec for Permission.
Derive EqDec for Capability.
Derive EqDec for RegName.

Derive EqDec for Enums.
Derive EqDec for Unions.
Derive EqDec for Records.
Derive EqDec for Instruction.
Derive EqDec for InstructionConstructor.

Module CapTypeKit <: TypeKit.

  (** ENUMS **)
  Definition 𝑬        := Enums.
  Definition 𝑬𝑲 (e : 𝑬) : Set :=
    match e with
    | permission => Permission
    | regname    => RegName
    end.
  Program Instance Blastable_𝑬𝑲 e : Blastable (𝑬𝑲 e) :=
    {| blast v POST := POST v |}.
  Solve All Obligations with auto.

  Definition 𝑼        := Unions.
  Definition 𝑼𝑻 (U : 𝑼) : Set :=
    match U with
    | instruction => Instruction
    end.
  Definition 𝑼𝑲 (U : 𝑼) : Set :=
    match U with
    | instruction => InstructionConstructor
    end.
  Program Instance Blastable_𝑼𝑲 U : Blastable (𝑼𝑲 U) :=
    match U with
    | instruction => {| blast v POST := POST v |}
    end.
  Solve All Obligations with destruct a; intuition congruence.

  Definition 𝑹        := Records.
  Definition 𝑹𝑻 (R : 𝑹) : Set :=
    match R with
    | addr       => Addr
    | capability => Capability
    end.

  Definition 𝑿        := string.

  Definition 𝑬_eq_dec := Enums_eqdec.
  Definition 𝑬𝑲_eq_dec : forall (e : 𝑬), EqDec (𝑬𝑲 e).
  Proof. intros []; cbn; auto with typeclass_instances. Defined.
  Definition 𝑼_eq_dec := Unions_eqdec.
  Definition 𝑼𝑻_eq_dec : forall (u : 𝑼), EqDec (𝑼𝑻 u).
  Proof. intros []; cbn; auto with typeclass_instances. Defined.
  Definition 𝑼𝑲_eq_dec : forall (u : 𝑼), EqDec (𝑼𝑲 u).
  Proof. intros []; cbn; auto with typeclass_instances. Defined.
  Definition 𝑹_eq_dec := Records_eqdec.
  Definition 𝑹𝑻_eq_dec : forall (r : 𝑹), EqDec (𝑹𝑻 r).
  Proof. intros []; cbn; auto with typeclass_instances. Defined.
  Definition 𝑿_eq_dec := string_dec.

  Definition 𝑺        := string.
  Definition 𝑺_eq_dec := string_dec.
  Definition 𝑿to𝑺 (x : 𝑿) : 𝑺 := x.

End CapTypeKit.
Module CapTypes := Types CapTypeKit.
Import CapTypes.

Definition ty_hv : Ty := ty_enum regname.
Definition ty_lv : Ty := ty_enum regname.
Definition ty_rv : Ty := (ty_sum (ty_enum regname) ty_int).

(*** TERMS ***)

Module CapTermKit <: (TermKit CapTypeKit).
  Module TY := CapTypes.

  (** UNIONS **)
  Definition 𝑼𝑲_Ty (U : 𝑼) : 𝑼𝑲 U -> Ty :=
    match U with
    | instruction => fun K =>
      match K with
      | kjmp      => ty_lv
      | kjnz      => ty_prod ty_lv ty_rv
      | kmove     => ty_prod ty_lv ty_rv
      | kload     => ty_prod ty_lv ty_hv
      | kstore    => ty_prod ty_hv ty_rv
      | klt       => ty_prod ty_lv (ty_prod ty_rv ty_rv)
      | kplus     => ty_prod ty_lv (ty_prod ty_rv ty_rv)
      | kminus    => ty_prod ty_lv (ty_prod ty_rv ty_rv)
      | klea      => ty_prod ty_lv ty_rv
      | krestrict => ty_prod ty_lv ty_rv
      | ksubseg   => ty_prod ty_lv (ty_prod ty_rv ty_rv)
      | kisptr    => ty_prod ty_lv ty_rv
      | kgetp     => ty_prod ty_lv ty_lv
      | kgetb     => ty_prod ty_lv ty_lv
      | kgete     => ty_prod ty_lv ty_lv
      | kgeta     => ty_prod ty_lv ty_lv
      | kfail     => ty_unit
      | khalt     => ty_unit
      end
    end.

  Definition 𝑼_fold (U : 𝑼) : { K : 𝑼𝑲 U & Lit (𝑼𝑲_Ty U K) } -> 𝑼𝑻 U :=
    match U with
    | instruction => fun Kv =>
      match Kv with
      | existT kjmp      lv                 => jmp lv
      | existT kjnz      (lv , rv)          => jnz lv rv
      | existT kmove     (lv , rv)          => move lv rv
      | existT kload     (lv , hv)          => load lv hv
      | existT kstore    (hv , rv)          => store hv rv
      | existT klt       (lv , (rv1 , rv2)) => lt lv rv1 rv2
      | existT kplus     (lv , (rv1 , rv2)) => plus lv rv1 rv2
      | existT kminus    (lv , (rv1 , rv2)) => minus lv rv1 rv2
      | existT klea      (lv , rv)          => lea lv rv
      | existT krestrict (lv , rv)          => restrict lv rv
      | existT ksubseg   (lv , (rv1 , rv2)) => subseg lv rv1 rv2
      | existT kisptr    (lv , rv)          => isptr lv rv
      | existT kgetp     (lv , lv')         => getp lv lv'
      | existT kgetb     (lv , lv')         => getb lv lv'
      | existT kgete     (lv , lv')         => gete lv lv'
      | existT kgeta     (lv , lv')         => geta lv lv'
      | existT kfail     tt                 => fail
      | existT khalt     tt                 => halt
      end
    end.
  Definition 𝑼_unfold (U : 𝑼) : 𝑼𝑻 U -> { K : 𝑼𝑲 U & Lit (𝑼𝑲_Ty U K) } :=
    match U as u return (𝑼𝑻 u -> {K : 𝑼𝑲 u & Lit (𝑼𝑲_Ty u K)}) with
    | instruction => fun Kv =>
      match Kv with
      | jmp lv            => existT kjmp      lv
      | jnz lv rv         => existT kjnz      (lv , rv)
      | move lv rv        => existT kmove     (lv , rv)
      | load lv hv        => existT kload     (lv , hv)
      | store hv rv       => existT kstore    (hv , rv)
      | lt lv rv1 rv2     => existT klt       (lv , (rv1 , rv2))
      | plus lv rv1 rv2   => existT kplus     (lv , (rv1 , rv2))
      | minus lv rv1 rv2  => existT kminus    (lv , (rv1 , rv2))
      | lea lv rv         => existT klea      (lv , rv)
      | restrict lv rv    => existT krestrict (lv , rv)
      | subseg lv rv1 rv2 => existT ksubseg   (lv , (rv1 , rv2))
      | isptr lv rv       => existT kisptr    (lv , rv)
      | getp lv lv'       => existT kgetp     (lv , lv')
      | getb lv lv'       => existT kgetb     (lv , lv')
      | gete lv lv'       => existT kgete     (lv , lv')
      | geta lv lv'       => existT kgeta     (lv , lv')
      | fail              => existT kfail     tt
      | halt              => existT khalt     tt
      end
    end.
  Lemma 𝑼_fold_unfold : forall (U : 𝑼) (Kv: 𝑼𝑻 U),
      𝑼_fold U (𝑼_unfold U Kv) = Kv.
  Proof. now intros [] []. Qed.
  Lemma 𝑼_unfold_fold : forall (U : 𝑼) (Kv: { K : 𝑼𝑲 U & Lit (𝑼𝑲_Ty U K) }),
      𝑼_unfold U (𝑼_fold U Kv) = Kv.
  Proof.
    intros [] [[] x]; cbn in x;
      repeat match goal with
             | x: unit     |- _ => destruct x
             | x: prod _ _ |- _ => destruct x
             end; auto.
  Qed.

  (** RECORDS **)
  Definition 𝑹𝑭  : Set := string.
  Print Capability.
  Definition 𝑹𝑭_Ty (R : 𝑹) : Ctx (𝑹𝑭 * Ty) :=
    match R with
    | addr       => [ "addr_int"       ∶ ty_int ]
    | capability => [ "cap_permission" ∶ ty_enum permission,
                      "cap_begin"      ∶ ty_record addr,
                      "cap_end"        ∶ ty_option (ty_record addr),
                      "cap_cursor"     ∶ ty_record addr
                    ]
    end.

  Definition 𝑹_fold (R : 𝑹) : NamedEnv Lit (𝑹𝑭_Ty R) -> 𝑹𝑻 R :=
    match R with
    | addr       =>
      fun fields =>
        MkAddr (fields ‼ "addr_int")
    | capability =>
      fun fields =>
        MkCap
          (fields ‼ "cap_permission")
          (fields ‼ "cap_begin")
          (fields ‼ "cap_end")
          (fields ‼ "cap_cursor")
    end%lit.

  Definition 𝑹_unfold (R : 𝑹) : 𝑹𝑻 R -> NamedEnv Lit (𝑹𝑭_Ty R) :=
    match R  with
    | addr       =>
      fun a =>
        env_nil
          ► "addr_int" ∶ ty_int ↦ addr_int a
    | capability =>
      fun c=>
        env_nil
          ► "cap_permission" ∶ ty_enum permission         ↦ cap_permission c
          ► "cap_begin"      ∶ ty_record addr             ↦ cap_begin c
          ► "cap_end"        ∶ ty_option (ty_record addr) ↦ cap_end c
          ► "cap_cursor"     ∶ ty_record addr             ↦ cap_cursor c
    end%env.
  Lemma 𝑹_fold_unfold : forall (R : 𝑹) (Kv: 𝑹𝑻 R),
      𝑹_fold R (𝑹_unfold R Kv) = Kv.
  Proof. now intros [] []. Qed.
  Lemma 𝑹_unfold_fold : forall (R : 𝑹) (Kv: NamedEnv Lit (𝑹𝑭_Ty R)),
      𝑹_unfold R (𝑹_fold R Kv) = Kv.
  Proof. intros []; now apply Forall_forall. Qed.

  (** FUNCTIONS **)
  Inductive Fun : Ctx (𝑿 * Ty) -> Ty -> Set :=
  .

  Definition 𝑭  : Ctx (𝑿 * Ty) -> Ty -> Set := Fun.

  Inductive Reg : Ty -> Set :=
    | pc   : Reg ty_int
    | reg0 : Reg ty_int
    | reg1 : Reg ty_int
    | reg2 : Reg ty_int
    | reg3 : Reg ty_int.

  Definition 𝑹𝑬𝑮 : Ty -> Set := Reg.
  Definition 𝑹𝑬𝑮_eq_dec {σ τ} (x : 𝑹𝑬𝑮 σ) (y : 𝑹𝑬𝑮 τ) : {x ≡ y}+{~ x ≡ y}.
  Proof.
    destruct x; destruct y; cbn;
      first
        [ left; now apply teq_refl with eq_refl
        | right; intros [eqt eqr];
          try rewrite <- (Eqdep_dec.eq_rect_eq_dec Ty_eq_dec) in eqr; discriminate
        ].
  Defined.

  Definition 𝑨𝑫𝑫𝑹 : Set := Addr.

End CapTermKit.
Module CapTerms := Terms CapTypeKit CapTermKit.
Import CapTerms.
Import NameResolution.
