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

From Katamaran Require Import
     Base
     Program
     Syntax.Formulas
     Syntax.Chunks
     Syntax.Predicates
     Syntax.Assertions.

Local Set Implicit Arguments.

Module Type ContractDeclMixin (B : Base) (Import P : Program B) (PK : PredicateKit B).

  Include FormulasOn B PK <+ ChunksOn B PK <+ AssertionsOn B PK.

  Definition SepContractEnv : Type :=
    forall Δ τ (f : 𝑭 Δ τ), option (SepContract Δ τ).
  Definition SepContractEnvEx : Type :=
    forall Δ τ (f : 𝑭𝑿 Δ τ), SepContract Δ τ.
  Definition LemmaEnv : Type :=
    forall Δ (l : 𝑳 Δ), Lemma Δ.

End ContractDeclMixin.

Module Type ContractDecl (B : Base) (P : Program B) :=
  PredicateKit B <+ ContractDeclMixin B P.

Module Type ContractDefKit (B : Base) (Import P : Program B) (Import PD : ContractDecl B P).

  Parameter Inline CEnv   : SepContractEnv.
  Parameter Inline CEnvEx : SepContractEnvEx.
  Parameter Inline LEnv   : LemmaEnv.

End ContractDefKit.
