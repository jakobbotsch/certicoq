Require Import L4.instances.


From CertiCoq.Common Require Import certiClasses certiClassesLinkable classes RandyPrelude AstCommon.

Require Import Coq.Unicode.Utf8 Coq.Strings.String.

Require Import ZArith.
From CertiCoq Require Import
     L6.cps L6.cps_util L6.state L6.eval L6.shrink_cps L6.L4_to_L6_anf L6.L5_to_L6
     L6.beta_contraction L6.uncurry L6.closure_conversion
     L6.closure_conversion L6.hoisting L6.dead_param_elim L6.lambda_lifting L6.toplevel.
(* From CertiCoq.L7 Require Import L6_to_Clight. *)
Require Import ExtLib.Structures.Monad.

Import MonadNotation.
Open Scope monad_scope.

(*
   Environment for L6 programs:
   1 - environment of primitive operations
   2 - environment of constructors (from which datatypes can be reconstructed)
   3 - name environment mapping variables to their original name if it exists
   4 - a map from function tags to information about that class of function
*)

Local Definition L6env : Type := prims * ctor_env *  cps_util.name_env * fun_env.

Local Definition L6term: Type := env * cps.exp.

Local Definition L6val: Type := cps.val.

(* A: Should pr cenv env be particular values? The translation from L5a doesn't produce
  these values. If it did, we could make the terms contain this information, as in L3 *)
(* Z: pr is the primitive functions map. I don't know where it's populated or it's purpose
   in general. cenv is the tag map which maps constructor tags to info such as arity and
   which type they belong to. env is the environment that contains valuations for the free
   variables of a term.
 *)

Instance bigStepOpSemL6Term : BigStepOpSem (L6env * L6term) L6val :=
  λ p v,
  let '(pr, cenv, nenv, fenv, (rho, e)) := p in
  (* should not modify pr, cenv and nenv *)
  ∃ (n:nat), L6.eval.bstep_e pr cenv rho e v n.

Require Import certiClasses2.


(* Probably want some fact about the wellformedness of L6env w.r.t. L6term *)
Instance WfL6Term : GoodTerm (L6env * L6term) :=
  fun p =>  let '(pr, cenv, nenv, fenv, (rho, e)) := p in
         identifiers.closed_exp e /\
         identifiers.unique_bindings e.

(* FIX!! *)
Global Instance QuestionHeadTermL : QuestionHead L6val :=
fun q t => false.

(* FIX!! *)
Global Instance ObsSubtermL : ObserveNthSubterm L6val :=
fun n t => None.

Instance certiL6 : CerticoqLanguage (L6env * L6term) := {}.
Eval compute in cValue certiL6.

(* Instance L6_evaln: BigStepOpSemExec (cTerm certiL6) (cValue certiL6) := *)
(*   fun n p => *)
(*     let '((penv, cenv, nenv, fenv), (rho, e)) := p in *)
(*     match bstep_f penv cenv rho e n with *)
(*     | exceptionMonad.Exc s => Error s None *)
(*     | Ret (inl t) => OutOfTime ((penv,cenv,nenv, fenv), t) *)
(*     | Ret (inr v) => Result v *)
(*     end. *)

Open Scope positive_scope.

(* starting tags for L5_to_L6, anything under default is reserved for special constructors/types *)
Definition default_ctor_tag := 99%positive.
Definition default_ind_tag := 99%positive.

(* assigned for the constructor and the type of closures *)
Definition bogus_closure_tag := 15%positive.
Definition bogus_cloind_tag := 16%positive.

(* tags for functions and continuations *)
<<<<<<< HEAD
Definition fun_fTag := 3%positive.
Definition kon_fTag := 2%positive.

(* Let bindings for function and enviroment.
 * Thee function and the argument should be closed terms
 * so we do not care about capturing *)
Definition f' := 1%positive.
Definition Γ := 2%positive.

(* This is application of closure converted functions.
   We will need regural application as well. It's likely that
   only this one will be exposed. *)
(* Instance CloApp : MkApply L6term := *)
(*   mkApp (fun f xs =>  *)
(*            Eproj f' bogus_clo_tag 0%N f *)
(*                  (Eproj Γ bogus_clo_tag 1%N f *)
(*                         (Eapp f' t (Γ :: xs)))). *)
  

Instance certiL5_t0_L6: 
  CerticoqTranslation (cTerm certiL5) (cTerm certiL6) := 
  fun v =>
    match v with
    | pair venv vt =>
      (match convert_top default_cTag default_iTag fun_fTag kon_fTag (venv, vt) with
      | Some r =>         
        let '(cenv, nenv, fenv, next_cTag, next_iTag, e) :=  r in
        let '(e, (d, s), fenv) := uncurry_fuel 100 (shrink_cps.shrink_top e) fenv in   
        (* let e := postuncurry_contract e s d in            *)
        (* let e := shrink_cps.shrink_top e in  *)
        (* let e :=  inlinesmall_contract e 10 10 in *)
        let e := inline_uncurry_contract e s 10 10 in  
=======
Definition fun_fun_tag := 3%positive.
Definition kon_fun_tag := 2%positive.

Require Import ExtLib.Data.Monads.OptionMonad.

Require Import ExtLib.Structures.Monads.


(* Definition L6_pipeline_old (e : cTerm certiL5) : exceptionMonad.exception (cTerm certiL6) := *)
(*   let (venv, vt) := e in *)
(*   match AstCommon.timePhase "L5 to L6" (fun (_:Datatypes.unit) => convert_top default_ctor_tag default_ind_tag fun_fun_tag kon_fun_tag (venv, vt)) with *)
(*   | Some r => *)
(*     let '(c_env, n_env, f_env, next_ctor_tag, next_ind_tag, e) := r in *)
(*     (* make compilation state *) *)
(*     let c_data := *)
(*         let next_var := ((identifiers.max_var e 1) + 1)%positive in *)
(*         let next_fun_tag := M.fold (fun cm => fun ft => fun _ => Pos.max cm ft) f_env 1 + 1 in *)
(*         pack_data next_var next_ctor_tag next_ind_tag next_fun_tag c_env f_env n_env nil *)
(*     in *)
(*     let res : error (exp * comp_data):= (* uncurring *) *)
(*         let '(e_err, s, c_data) := uncurry_fuel_cps 100 (shrink_cps.shrink_top e) c_data in *)
(*         (* (* inlining *) *) *)
(*         e <- e_err ;; *)
(*         let (e_err, c_data) := inline_uncurry e s 10 10 c_data in *)
(*         e <- e_err ;; *)
(*         (* Shrink reduction *) *)
(*         let e := shrink_cps.shrink_top e in *)
(*         let '(mkCompData next ctag itag ftag cenv fenv names log) := c_data in *)
(*         let '(cenv', names', e) := *)
(*             closure_conversion.closure_conversion_hoist bogus_closure_tag e ctag itag cenv names in *)
(*         let c_data := *)
(*             let next_var := ((identifiers.max_var e 1) + 1)%positive in *)
(*             pack_data next_var ctag itag ftag (add_closure_tag bogus_closure_tag bogus_cloind_tag cenv') fenv names' log *)
(*         in *)
(*         (* Shrink reduction *) *)
(*         let e := shrink_cps.shrink_top e in *)
(*         (* Dead parameter elimination *) *)
(*         let e := dead_param_elim.eliminate e in *)
(*         (* Shrink reduction *) *)
(*         ret (shrink_cps.shrink_top e, c_data) *)
(*     in *)
(*     match res with *)
(*     | Err s => *)
(*       exceptionMonad.Exc ("failed converting from L5 to L6 (anf) : " ++ s)%string *)
(*     | Ret (e, c_data) => *)
(*       exceptionMonad.Ret *)
(*         ((M.empty _ ,  state.cenv c_data, state.nenv c_data, state.fenv c_data), (M.empty _, e)) *)
(*     end *)
(*   | None => exceptionMonad.Exc "failed converting from L5 to L6" *)
(*   end. *)

Definition L6_pipeline_anf (opt : bool) (e : cTerm certiL4)  : exceptionMonad.exception (cTerm certiL6) :=
  let (venv, vt) := e in
  let res : error (exp * comp_data) := 
      (* L4 to L6 anf *)
      let (e_err, c_data) := convert_top_anf fun_fun_tag default_ctor_tag default_ind_tag (venv, vt) in
      e <- e_err ;;
      (* uncurring *)
      let '(e_err, s, c_data) := uncurry_fuel_anf 100 (shrink_cps.shrink_top e) c_data in
      e <- e_err ;;
      (* inlining *)
      let (e_err, c_data) := inline_uncurry_marked_anf e s 10 10 c_data in
      e <- e_err ;;
      (* (* Shrink reduction *) *)
      let e := shrink_cps.shrink_top e in
      (* lambda lifting *)
      let (e_rr, c_data) := if opt then lambda_lift e c_data else (Ret e, c_data)in
      e <- e_rr ;; 
      (* Shrink reduction *)
      let e := shrink_cps.shrink_top e in
      (* Closure conversion *)
      let (e_err, c_data) := closure_conversion.closure_conversion_hoist bogus_closure_tag (* bogus_cloind_tag *) e c_data in
      let '(mkCompData next ctag itag ftag cenv fenv names log) := c_data in
      let c_data :=
          let next_var := ((identifiers.max_var e 1) + 1)%positive in
          pack_data next_var ctag itag ftag (add_closure_tag bogus_closure_tag bogus_cloind_tag cenv) fenv (add_binders_exp names e) log
      in
      e <- e_err ;;
      (* Shrink reduction *)
      let e := shrink_cps.shrink_top e in
      (* Dead parameter elimination *)
      (* let e := dead_param_elim.eliminate e in *)
      (* Shrink reduction *)
      ret (shrink_cps.shrink_top e, c_data)
  in
  match res with
  | Err s =>
    exceptionMonad.Exc ("failed converting from L5 to L6 (anf) : " ++ s)%string
  | Ret (e, c_data) =>
    exceptionMonad.Ret
      ((M.empty _ ,  state.cenv c_data, state.nenv c_data, state.fenv c_data), (M.empty _, e))
  end.

Definition L6_pipeline_pre_cc (opt : bool) (e : cTerm certiL4)  : exceptionMonad.exception (cTerm certiL6) :=
  let (venv, vt) := e in
  let res : error (exp * comp_data) := 
      (* L4 to L6 anf *)
      let (e_err, c_data) := convert_top_anf fun_fun_tag default_ctor_tag default_ind_tag (venv, vt) in
      e <- e_err ;;
      (* uncurring *)
      let '(e_err, s, c_data) := uncurry_fuel_anf 100 (shrink_cps.shrink_top e) c_data in
      e <- e_err ;;
      (* inlining *)
      let (e_err, c_data) := inline_uncurry_marked_anf e s 10 10 c_data in
      e <- e_err ;;
      (* (* Shrink reduction *) *)
      (* let e := shrink_cps.shrink_top e in *)
      (* (* Dead parameter elimination *) *)
      (* let e := dead_param_elim.eliminate e in *)
      (* Shrink reduction *)
      ret (shrink_cps.shrink_top e, c_data)
  in
  match res with
  | Err s =>
    exceptionMonad.Exc ("failed converting from L5 to L6 (anf) : " ++ s)%string
  | Ret (e, c_data) =>
    exceptionMonad.Ret
      ((M.empty _ ,  state.cenv c_data, state.nenv c_data, state.fenv c_data), (M.empty _, e))
  end.

Definition L4_to_L6_anf (opt : bool) (e : cTerm certiL4)  : exceptionMonad.exception (cTerm certiL6) :=
  let (venv, vt) := e in
  let res : error (exp * comp_data) := 
      (* L4 to L6 anf *)
      let (e_err, c_data) := convert_top_anf fun_fun_tag default_ctor_tag default_ind_tag (venv, vt) in
      e <- e_err ;;
      (* (* uncurring *) *)
      (* let '(e_err, s, c_data) := uncurry_fuel_anf 100 (shrink_cps.shrink_top e) c_data in *)
      (* e <- e_err ;; *)
      (* (* inlining *) *)
      (* let (e_err, c_data) := inline_uncurry_marked_anf e s 10 10 c_data in *)
      (* e <- e_err ;; *)
      (* (* Shrink reduction *) *)
      (* let e := shrink_cps.shrink_top e in *)
      (* (* Dead parameter elimination *) *)
      (* let e := dead_param_elim.eliminate e in *)
      (* Shrink reduction *)
      ret ((* shrink_cps.shrink_top *) e, c_data)
  in
  match res with
  | Err s =>
    exceptionMonad.Exc ("failed converting from L5 to L6 (anf) : " ++ s)%string
  | Ret (e, c_data) =>
    exceptionMonad.Ret
      ((M.empty _ ,  state.cenv c_data, state.nenv c_data, state.fenv c_data), (M.empty _, e))
  end.


(* Optimizing L6 pipeline *)
Definition L6_pipeline  (opt : bool) (e : cTerm certiL5) : exceptionMonad.exception (cTerm certiL6) :=
  let (venv, vt) := e in
  match AstCommon.timePhase "L5 to L6" (fun (_:Datatypes.unit) => convert_top default_ctor_tag default_ind_tag fun_fun_tag kon_fun_tag (venv, vt)) with
  | Some r =>
    let '(c_env, n_env, f_env, next_ctor_tag, next_ind_tag, e) := r in
    (* make compilation state *)
    let c_data :=
        let next_var := ((identifiers.max_var e 1) + 1)%positive in
        let next_fun_tag := M.fold (fun cm => fun ft => fun _ => Pos.max cm ft) f_env 1 + 1 in
        pack_data next_var next_ctor_tag next_ind_tag next_fun_tag c_env f_env n_env nil
    in
    let res : error (exp * comp_data):= (* uncurring *)
        let '(e_err, s, c_data) := uncurry_fuel_cps 100 (shrink_cps.shrink_top e) c_data in
        (* (* inlining *) *)
        e <- e_err ;;
        let (e_err, c_data) := inline_uncurry e s 10 10 c_data in
        e <- e_err ;;
        (* Shrink reduction *)
>>>>>>> 7822872cef2ae52868945e60a30fb5cbc00b5589
        let e := shrink_cps.shrink_top e in
        (* lambda lifting *)
        let (e_rr, c_data) := if opt then lambda_lift e c_data else (Ret e, c_data)in
        e <- e_rr ;; 
        (* Shrink reduction *)
        let e := shrink_cps.shrink_top e in
        (* Closure conversion *)
        let (e_err, c_data) := closure_conversion.closure_conversion_hoist bogus_closure_tag (* bogus_cloind_tag *) e c_data in
        let '(mkCompData next ctag itag ftag cenv fenv names log) := c_data in
        let c_data :=
            let next_var := ((identifiers.max_var e 1) + 1)%positive in
            pack_data next_var ctag itag ftag (add_closure_tag bogus_closure_tag bogus_cloind_tag cenv) fenv (add_binders_exp names e) log
        in
        e <- e_err ;;
        (* Shrink reduction *)
        let e := shrink_cps.shrink_top e in
        (* Dead parameter elimination *)
        (* let e := dead_param_elim.eliminate e in *)
        (* Shrink reduction *)
        ret (shrink_cps.shrink_top e, c_data)
    in
    match res with
    | Err s =>
      exceptionMonad.Exc ("failed converting from L5 to L6 (anf) : " ++ s)%string
    | Ret (e, c_data) =>
      exceptionMonad.Ret
        ((M.empty _ ,  state.cenv c_data, state.nenv c_data, state.fenv c_data), (M.empty _, e))
    end
  | None => exceptionMonad.Exc "failed converting from L5 to L6"
  end.

(* Instance certiL4_t0_L6: *)
(*   CerticoqTranslation (cTerm certiL4) (cTerm certiL6) := *)
(*   fun o => match o with *)
(*         | Flag 0 => L6_pipeline_anf false *)
(*         | Flag 1 => L6_pipeline_anf true *)
(*         | Flag _ => L6_pipeline_anf false *)
(*         end. *)

Instance certiL5_t0_L6:
  CerticoqTranslation (cTerm certiL5) (cTerm certiL6) :=
  fun o => match o with
        | Flag 0 => L6_pipeline false
        | Flag 1 => L6_pipeline true
        | _ => L6_pipeline false
        end.
