
Require Import Coq.Lists.List.
Require Import Coq.Strings.String.
Require Import Coq.Arith.Compare_dec.
Require Import Coq.Program.Basics.
Require Import Coq.omega.Omega.
Require Import Coq.Logic.Decidable.
Require Import Common.Common.
Require Import L2d.compile.
Require Import L2d.term.
Require Import L2d.program.

Local Open Scope string_scope.
Local Open Scope bool.
Local Open Scope list.
Set Implicit Arguments.

(** Relational version of weak cbv evaluation  **)
Inductive WcbvEval (p:environ Term) : Term -> Term -> Prop :=
| wLam: forall nm bod, WcbvEval p (TLambda nm bod) (TLambda nm bod)
| wProof: WcbvEval p TProof TProof
| wAppProof fn arg :
    WcbvEval p fn TProof ->
    WcbvEval p (TApp fn arg) TProof
| wConstruct: forall i r np na,
    WcbvEval p (TConstruct i r np na) (TConstruct i r np na)
| wFix: forall dts m, WcbvEval p (TFix dts m) (TFix dts m)
| wConst: forall nm (t s:Term),
    lookupDfn nm p = Ret t -> WcbvEval p t s ->
    WcbvEval p (TConst nm) s
| wAppLam: forall (fn bod a1 a1' s:Term) (nm:name),
    WcbvEval p fn (TLambda nm bod) ->
    WcbvEval p a1 a1' ->
    WcbvEval p (whBetaStep bod a1') s ->
    WcbvEval p (TApp fn a1) s
| wLetIn: forall (nm:name) (dfn bod dfn' s:Term),
    WcbvEval p dfn dfn' ->
    WcbvEval p (instantiate dfn' 0 bod) s ->
    WcbvEval p (TLetIn nm dfn bod) s
| wAppFix: forall dts m (fn arg s x:Term),
    WcbvEval p fn (TFix dts m) ->
    dnthBody m dts = Some x ->
    WcbvEval p (pre_whFixStep x dts arg) s ->
    WcbvEval p (TApp fn arg) s 
| wAppCong: forall fn fn' arg arg', 
    WcbvEval p fn fn' -> (isConstruct fn' \/ isApp fn' \/ isDummy fn') ->
    WcbvEval p arg arg' ->
    WcbvEval p (TApp fn arg) (TApp fn' arg')
| wCase: forall mch Mch n args ml ts brs cs s ,
    WcbvEval p mch Mch ->
    canonicalP Mch = Some (n, args) ->
    tskipn (snd ml) args = Some ts ->
    whCaseStep n ts brs = Some cs ->
    WcbvEval p cs s ->
    WcbvEval p (TCase ml mch brs) s
| wDummy: forall str, WcbvEval p (TDummy str) (TDummy str)
with WcbvEvals (p:environ Term) : Terms -> Terms -> Prop :=
| wNil: WcbvEvals p tnil tnil
| wCons: forall t t' ts ts',
    WcbvEval p t t' -> WcbvEvals p ts ts' -> 
    WcbvEvals p (tcons t ts) (tcons t' ts').
Hint Constructors WcbvEvals WcbvEval : core.
Scheme WcbvEval1_ind := Induction for WcbvEval Sort Prop
  with WcbvEvals1_ind := Induction for WcbvEvals Sort Prop.
Combined Scheme WcbvEvalEvals_ind from WcbvEval1_ind, WcbvEvals1_ind.

(** when reduction stops **)
Definition no_Wcbv_step (p:environ Term) (t:Term) : Prop :=
  no_step (WcbvEval p) t.

(** evaluate omega = (\x.xx)(\x.xx): nontermination **)
Definition xx := TLambda nAnon (TApp (TRel 0) (TRel 0)).
Definition xxxx := TApp xx xx.
Goal WcbvEval nil xxxx xxxx.
Proof.
  unfold xxxx, xx. eapply wAppLam.
  - constructor.
  - eapply wLam.
  - cbn. change (WcbvEval nil xxxx xxxx).
Abort.
             
Lemma WcbvEvals_tappend:
  forall ts ets p us eus,
    WcbvEvals p ts ets -> WcbvEvals p us eus ->
    WcbvEvals p (tappend ts us) (tappend ets eus).
Proof.
  induction ts; intros.
  - inversion_Clear H. cbn. assumption.
  - inversion_Clear H. cbn. constructor; intuition.
Qed.

Lemma WcbvEval_single_valued:
  forall p,
  (forall t s, WcbvEval p t s -> forall u, WcbvEval p t u -> s = u) /\
  (forall ts ss, WcbvEvals p ts ss ->
                 forall us, WcbvEvals p ts us -> ss = us).
Proof.
  intros p.
  apply WcbvEvalEvals_ind; intros; try (inversion_Clear H; reflexivity).
  - eapply H. inversion_Clear H0. assumption.
    apply H in H3; discriminate.
    apply H in H3; discriminate.
    apply H in H3. subst fn'.
    destruct H4 as [H4|[H4|H4]]; red in H4.
    destruct H4 as (?&?&?&?&H4); discriminate.
    destruct H4 as (?&?&H4); discriminate.
    destruct H4 as (?&H4). discriminate.
  - eapply H. inversion_Clear H0. rewrite e in H2.
    myInjection H2. assumption.
  - inversion_Clear H2;
      try (specialize (H _ H6); discriminate);
      try (specialize (H _ H5); discriminate).
    + specialize (H _ H5). myInjection H.
      specialize (H0 _ H6). subst. 
      intuition.
    + specialize (H _ H5). subst. destruct H6; try is_inv H.
      destruct H; try is_inv H.
  - inversion_Clear H1;
      try (specialize (H _ H4); discriminate).
    + specialize (H _ H6). subst. specialize (H0 _ H7). assumption.
  - inversion_Clear H1;
    try (specialize (H _ H4); discriminate);
    try (specialize (H _ H5); discriminate).
    + specialize (H _ H4). myInjection H. rewrite e in H5. myInjection H5.
      intuition.
    + specialize (H _ H4). subst. destruct H5; try is_inv H.
      destruct H; try is_inv H.
  - inversion_Clear H1; (specialize (H _ H4) || specialize (H _ H5)); subst.
    + destruct o; try is_inv H. destruct H; try is_inv H.
    + destruct o; try is_inv H. destruct H; try is_inv H.
    + destruct o; try is_inv H. destruct H; try is_inv H.
    + specialize (H0 _ H7). subst. reflexivity.
  - inversion_Clear H1;
      try (specialize (IHWcbvEval1 _ H4); discriminate);
      try (specialize (IHWcbvEval1 _ H5); discriminate).
    + specialize (H _ H5). subst. rewrite e in H6. myInjection H6.
      rewrite e0 in H7. myInjection H7. rewrite e1 in H9. myInjection H9.
      intuition.
  - inversion_Clear H1. specialize (H _ H4). subst.
    specialize (H0 _ H6). subst. reflexivity.
Qed.
  
Lemma sv_cor:
  forall p fn fn' t s,
    WcbvEval p fn t -> WcbvEval p fn' t -> WcbvEval p fn s -> WcbvEval p fn' s.
Proof.
  intros. rewrite (proj1 (WcbvEval_single_valued p) _ _ H1 _ H). assumption.
Qed.
  
Lemma WcbvEval_no_further:
  forall p,
    (forall t s, WcbvEval p t s -> WcbvEval p s s) /\
    (forall t s, WcbvEvals p t s -> WcbvEvals p s s).
Proof.
  intros p; apply WcbvEvalEvals_ind; intros; auto.
Qed.

Lemma WcbvEval_trn:
  forall p s t,
    WcbvEval p s t ->
    forall u,
      WcbvEval p t u -> WcbvEval p s u.
Proof.
  intros.
  pose proof (proj1 (WcbvEval_no_further p) _ _ H) as j0.
  rewrite (proj1 (WcbvEval_single_valued p) _ _ H0 _ j0).
  assumption.
Qed.

(*******  move to somewhere  ********
Lemma WcbvEval_mkApp_nil:
  forall t, WFapp t -> forall p s, WcbvEval p t s ->
                 WcbvEval p (mkApp t tnil) s.
Proof.
  intros p. induction 1; simpl; intros; try assumption.
  - rewrite tappend_tnil. assumption.
Qed.

Lemma lookup_pres_WFapp:
    forall p, WFaEnv p -> forall nm ec, lookup nm p = Some ec -> WFaEc ec.
Proof.
  induction 1; intros nn ed h.
  - inversion_Clear h.
  - case_eq (string_eq_bool nn nm); intros j.
    + cbn in h. rewrite j in h. myInjection h. assumption.
    + cbn in h. rewrite j in h. eapply IHWFaEnv. eassumption.
Qed.
**************************************************)

(*****
Lemma WcbvEvals_tcons_tcons:
  forall p arg args brgs, WcbvEvals p (tcons arg args) brgs ->
                          exists crg crgs, brgs = (tcons crg crgs).
Proof.
  inversion 1. exists t', ts'. reflexivity.
Qed.

Lemma WcbvEvals_tcons_tcons':
  forall p arg brg args brgs,
    WcbvEvals p (tcons arg args) (tcons brg brgs) ->
    WcbvEval p arg brg /\ WcbvEvals p args brgs.
Proof.
  inversion 1. intuition.
Qed.

Lemma WcbvEvals_pres_tlength:
  forall p args brgs, WcbvEvals p args brgs -> tlength args = tlength brgs.
Proof.
  induction 1. reflexivity. cbn. rewrite IHWcbvEvals. reflexivity.
Qed.
 ************)

(** wcbvEval preserves WFapp **
Lemma WcbvEval_pres_WFapp:
  forall p, WFaEnv p -> 
  (forall t s, WcbvEval p t s -> WFapp t -> WFapp s) /\
  (forall ts ss, WcbvEvals p ts ss -> WFapps ts -> WFapps ss).
Proof.
  intros p hp.
  apply WcbvEvalEvals_ind; intros; try assumption;
  try (solve[inversion_Clear H0; intuition]);
  try (solve[inversion_Clear H1; intuition]).
  - apply H. unfold lookupDfn in e. case_eq (lookup nm p); intros xc.
    + intros k. assert (j:= lookup_pres_WFapp hp _ k)
      . rewrite k in e. destruct xc. 
      * myInjection e. inversion j. assumption.
      * discriminate.
    + rewrite xc in e. discriminate.
  - inversion_clear H2. apply H1.
    specialize (H H4). inversion_Clear H.
    apply (whBetaStep_pres_WFapp); intuition. 
  - inversion_Clear H1. apply H0. apply instantiate_pres_WFapp; intuition.
  - inversion_clear H1. specialize (H H3). inversion_Clear H.
    apply H0. apply pre_whFixStep_pres_WFapp; try eassumption; intuition.
    + eapply dnthBody_pres_WFapp; try eassumption.
  - destruct o.
    + destruct H3 as [y0 [y1 [y2 [y3 jy]]]]. subst.
      inversion_Clear H2. econstructor; intuition.
      destruct H2 as [x0 [x1 [x2 jx]]]. discriminate.
    + unfold isInd in H3. subst.
      inversion_Clear H2. econstructor; intuition.
      destruct H2 as [x0 [x1 [x2 jx]]]. discriminate.  
  - apply H0. inversion_Clear H1. 
    refine (whCaseStep_pres_WFapp H6 _ _ e1). 
    refine (tskipn_pres_WFapp _ _ e0).
    refine (canonicalP_pres_WFapp _ e). intuition.
Qed.
 ************)

Lemma WcbvEval_weaken:
  forall p,
  (forall t s, WcbvEval p t s ->
                 forall nm ec, fresh nm p -> WcbvEval ((nm,ec)::p) t s) /\
  (forall t s, WcbvEvals p t s ->
                 forall nm ec, fresh nm p -> WcbvEvals ((nm,ec)::p) t s).
Proof.
  intros p. apply WcbvEvalEvals_ind; intros; auto.
  - destruct (string_dec nm nm0).
    + subst. 
      unfold lookupDfn in e.
      rewrite (proj1 (fresh_lookup_None (trm:=Term) _ _) H0) in e.
      discriminate.
    + eapply wConst.
      * rewrite <- (lookupDfn_weaken' n). eassumption. 
      * apply H. assumption. 
  - eapply wAppLam.
    + apply H. assumption.                           
    + apply H0. assumption.
    + apply H1. assumption.
  - eapply wLetIn; intuition.
  - eapply wAppFix; try eassumption; intuition.
  - eapply wCase; intuition; eassumption.
Qed.

(****
Lemma WcbvEval_mkApp_WcbvEval:
  forall p args s t,
    WcbvEval p (mkApp s args) t -> exists u, WcbvEval p s u.
Proof.
  induction args; intros.
  - rewrite mkApp_tnil in H. exists t. assumption.
  - cbn in *. specialize (IHargs _ _ H). destruct IHargs as [x jx].
    inversion_clear jx.
    + exists (TLambda nm bod). assumption.
    + exists TDummy. assumption.
    + exists (TApp fn1 arg1). assumption.
    + exists (TFix dts m). assumption.
    + exists (TConstruct i m np na). assumption.
Qed.
 ****)

(***
Lemma WcbvEval_strengthen:
  forall pp,
  (forall t s, WcbvEval pp t s -> forall nm ec p, pp = (nm,ec)::p ->
       Crct p 0 t -> WcbvEval p t s) /\
  (forall ts ss, WcbvEvals pp ts ss -> forall nm ec p, pp = (nm,ec)::p ->
       Crcts p 0 ts -> WcbvEvals p ts ss).
Proof.
  Admitted.
  intros pp. apply WcbvEvalEvals_ind; intros; auto; subst.
  - constructor. eapply H. reflexivity.
    destruct ec.
    + econstructor. try econstructor; try assumption.
    intros h. destruct H1. constructor. assumption.
  - assert (j:= not_eq_sym (notPocc_TConst H1)).
    assert (j1:= Lookup_strengthen l eq_refl j).
    econstructor.
    + unfold LookupDfn. eassumption.
    + eapply H. reflexivity. eapply (proj1 Crct_fresh_Pocc). eapply
       
      intros h. destruct H1. constructor. assumption.

Lemma WcbvEval_strengthen:
  forall pp, Crct pp 0 prop ->
  (forall t s, WcbvEval pp t s -> forall nm ec p, pp = (nm,ec)::p ->
       ~ PoccTrm nm t -> WcbvEval p t s) /\
  (forall ts ss, WcbvEvals pp ts ss -> forall nm ec p, pp = (nm,ec)::p ->
       ~ PoccTrms nm ts -> WcbvEvals p ts ss).
Proof.
  intros pp hpp. apply WcbvEvalEvals_ind; intros; auto; subst.
  - constructor. eapply H. reflexivity.
    intros h. destruct H1. constructor. assumption.
  - assert (j:= not_eq_sym (notPocc_TConst H1)).
    assert (j1:= Lookup_strengthen l eq_refl j).
    econstructor.
    + unfold LookupDfn. eassumption.
    + eapply H. reflexivity. eapply (proj1 Crct_fresh_Pocc). eapply
       
      intros h. destruct H1. constructor. assumption.
 **************)

(***
Lemma WcbvEval_pres_Crct:
  (forall p n t, Crct p n t ->
                 forall t', WcbvEval p t t' -> Crct p n t') /\
  (forall p n ts, Crcts p n ts ->
                  forall ts', WcbvEvals p ts ts' -> Crcts p n ts') /\
  (forall p n ds, CrctDs p n ds -> True) /\
  (forall p n itp, CrctTyp p n itp -> True).
Proof.
  apply CrctCrctsCrctDsTyp_ind; intros; try (solve[constructor; trivial]).
  - inversion_Clear H; constructor.
  - inversion_Clear H; constructor.
  - apply CrctWkTrmTrm; try assumption. apply H0.
    eapply (proj1 (WcbvEval_strengthen p)).


Goal    
  forall p, Crct p 0 prop ->
    (forall t t', WcbvEval p t t' -> Crct p 0 t) /\
    (forall ts ts', WcbvEvals p ts ts' -> Crcts p 0 ts).
Proof.
  intros p hp.
  apply WcbvEvalEvals_ind; intros; try (solve[constructor; trivial]).
  - eapply Crct_Prf. eassumption.
  - constructor.
    
Lemma WcbvEval_pres_Crct:
  forall p,
    (forall t t', WcbvEval p t t' -> Crct p 0 t -> Crct p 0 t') /\
    (forall ts ts', WcbvEvals p ts ts' -> Crcts p 0 ts -> Crcts p 0 ts').
Proof.
  intros p.
  apply WcbvEvalEvals_ind; intros; try reflexivity; try assumption;
  try (solve[constructor; trivial]).
  - apply H. inversion_Clear H0; try assumption.
    + apply (proj1 Crct_weaken); try assumption. apply (Crct_invrt_Cast H1).
      reflexivity.
    + apply (proj1 Crct_Typ_weaken); try assumption.
      apply (Crct_invrt_Cast H1). reflexivity.
  - apply H. destruct (Crct_invrt_Const H0 eq_refl) as [j0 [pd [j1 j2]]].
    unfold LookupDfn in *. assert (k:= Lookup_single_valued l j1).
    myInjection k. assumption.
  - apply H1. destruct (Crct_invrt_App H2 eq_refl) as [j0 [j1 [j2 j3]]].
    specialize (H j0).
    assert (j4:= Crct_invrt_Lam H eq_refl).
    apply whBetaStep_pres_Crct; try assumption.
    apply H0. assumption.
  - destruct (Crct_invrt_LetIn H1 eq_refl). apply H0.
    apply instantiate_pres_Crct; try assumption. apply H. assumption.
    omega.
  - destruct (Crct_invrt_App H1 eq_refl) as [j0 [j1 [j2 j3]]]. clear H1.
    specialize (H j0). assert (k:= Crct_invrt_Fix H eq_refl). clear H.    
    apply H0. unfold pre_whFixStep. apply mkApp_pres_Crct.
    apply fold_left_pres_Crct. intros. apply instantiate_pres_Crct; try omega.
    apply Crct_up; assumption.
    constructor; try assumption. eapply Crct_Sort; eassumption.
    refine (CrctDs_invrt _ _ e). cbn in k. admit.
    constructor; assumption.
  -

Qed.
****)

Section wcbvEval_sec.
Variable p:environ Term.

(** now an executable weak-call-by-value evaluation **)
(** use a timer to make this terminate **)
Function wcbvEval
         (tmr:nat) (t:Term) {struct tmr}: exception Term :=
  match tmr with 
  | 0 => raise ("out of time: " ++ print_term t)
  | S n =>
    match t with      (** look for a redex **)
    | TConst nm =>
      match (lookup nm p) with
      | Some (ecTrm t) => wcbvEval n t
      (** note hack coding of axioms in environment **)
      | Some (ecTyp _ _ _) => raise ("wcbvEval, TConst ecTyp " ++ nm)
      | _ => raise "wcbvEval: TConst environment miss"
      end
    | TProof => Ret TProof
    | TApp fn a1 =>
      match wcbvEval n fn with
      | Ret (TLambda _ bod) =>
        match wcbvEval n a1 with
        | Exc s =>  raise ("wcbvEval beta: arg doesn't eval: "
                             ++ print_term a1 ++ ";" ++ s)
        | Ret b1 => wcbvEval n (whBetaStep bod b1)
        end
      | Ret (TFix dts m) =>           (* Fix redex *)
        match dnthBody m dts with
        | None => raise ("wcbvEval TApp: dnthBody doesn't eval: ")
        | Some x => wcbvEval n (pre_whFixStep x dts a1)
        end
      | Ret ((TConstruct _ _ _ _) as tc)    (** congruence **)
      | Ret ((TApp _ _) as tc)
      | Ret ((TDummy _) as tc) =>
        match wcbvEval n a1 with
        | Ret a1' => ret (TApp tc a1')
        | Exc s => raise ("wcbvEval;TApp:arg doesn't eval: "
                   ++ print_term a1 ++ "; " ++ s)
        end
      | Ret TProof => Ret TProof
      | Ret tc => raise ("wcbvEval:TApp:fn cannot be applied: "
                           ++ print_term tc ++ ")")
      | Exc s =>
        raise ("wcbvEval:TApp:fn doesn't eval: "
                 ++ print_term fn ++ "; " ++ s)
      end
    | TCase ml mch brs =>
      match wcbvEval n mch with
      | Exc str => Exc str
      | Ret emch =>
        match canonicalP emch with
        | None => raise ("(wcbvEval:Case, discriminee not canonical: "
                           ++ print_term emch ++ ")")
        | Some (r, args) =>
          match tskipn (snd ml) args with
          | None => raise "wcbvEval: Case, tskipn"
          | Some ts =>
            match whCaseStep r ts brs with
            | None => raise "wcbvEval: Case,whCaseStep"
            | Some cs => wcbvEval n cs
            end
          end
        end
      end
    | TLetIn nm df bod =>
      match wcbvEval n df with
      | Ret df' => wcbvEval n (instantiate df' 0 bod)
      | Exc s => raise ("wcbvEval: TLetIn: " ++ s)
      end
    (** already in whnf ***)
    | (TConstruct _ _ _ _) as u 
    | (TLambda _ _) as u
    | (TFix _ _) as u
    | (TDummy _) as u => ret u
    (** should never appear **)
    | TRel _ => raise "wcbvEval: unbound Rel"
    | TWrong s => raise ("(TWrong:" ++ s ++")")
    end
  end
with wcbvEvals (tmr:nat) (ts:Terms) {struct tmr} : exception Terms :=
       match tmr with 
        | 0 => raise "out of time"
        | S n => match ts with             (** look for a redex **)
                 | tnil => ret tnil
                 | tcons s ss =>
                   match wcbvEval n s, wcbvEvals n ss with
                   | Ret es, Ret ess => ret (tcons es ess)
                   | Exc s, _ => raise s
                   | Ret _, Exc s => raise s
                   end
                 end
        end.
Functional Scheme wcbvEval_ind' := Induction for wcbvEval Sort Prop
with wcbvEvals_ind' := Induction for wcbvEvals Sort Prop.
Combined Scheme wcbvEvalEvals_ind from wcbvEval_ind', wcbvEvals_ind'.
 
(** wcbvEval and WcbvEval are the same relation **)
Lemma wcbvEval_WcbvEval:
  forall tmr,
  (forall t s, wcbvEval tmr t = Ret s -> WcbvEval p t s) /\
  (forall t s, wcbvEvals tmr t = Ret s -> WcbvEvals p t s).
Proof.
  apply (wcbvEvalEvals_ind
           (fun tmr t su => forall u (p1:su = Ret u), WcbvEval p t u)
           (fun tmr t su => forall u (p1:su = Ret u), WcbvEvals p t u));
    intros; try discriminate; try (myInjection p1);
      try(solve[constructor]); intuition.
  - eapply wConst; intuition.
    + unfold lookupDfn. rewrite e1. reflexivity.
  - specialize (H1 _ p1). specialize (H _ e1). specialize (H0 _ e2).
    eapply wAppLam; eassumption.
  - specialize (H0 _ p1). specialize (H _ e1).
    eapply wAppFix; try eassumption.
  - specialize (H _ e1). specialize (H0 _ e2).
    eapply wAppCong; try eassumption. left.
    exists _x, _x0, _x1, _x2. reflexivity.
  - specialize (H _ e1). specialize (H0 _ e2).
    eapply wAppCong; try eassumption. right. right. exists _x. reflexivity.
  - specialize (H _ e1). specialize (H0 _ p1).
    eapply wCase; try eassumption.
  - specialize (H _ e1). specialize (H0 _ p1).
    eapply wLetIn; eassumption.
Qed.

(** need strengthening to large-enough fuel to make the induction
 *** go through **)
Lemma pre_WcbvEval_wcbvEval:
  (forall t s, WcbvEval p t s ->
               exists n, forall m, m >= n -> wcbvEval (S m) t = Ret s) /\
  (forall ts ss, WcbvEvals p ts ss ->
                 exists n, forall m, m >= n -> wcbvEvals (S m) ts = Ret ss).
  assert (j:forall m, m > 0 -> m = S (m - 1)).
  { induction m; intuition. }
  apply WcbvEvalEvals_ind; intros; try (exists 0; intros mx h; reflexivity).
  - destruct H. exists (S x). intros m hm. simpl. rewrite (j m); try omega.
    + rewrite (H (m - 1)); try omega. reflexivity.
  - destruct H. exists (S x). intros mm h. simpl.
    rewrite (j mm); try omega.
    unfold lookupDfn in e. destruct (lookup nm p). destruct e0. myInjection e.
    + rewrite H. reflexivity. omega.
    + discriminate.
    + discriminate.
  - destruct H, H0, H1. exists (S (max x (max x0 x1))). intros m h.
    assert (j1:= max_fst x (max x0 x1)). 
    assert (lx: m > x). omega.
    assert (j2:= max_snd x (max x0 x1)).
    assert (j3:= max_fst x0 x1).
    assert (lx0: m > x0). omega.
    assert (j4:= max_snd x0 x1).
    assert (j5:= max_fst x0 x1).
    assert (lx1: m > x1). omega.
    assert (k:wcbvEval m fn = Ret (TLambda nm bod)).
    { rewrite (j m). apply H.
      assert (l:= max_fst x (max x0 x1)); omega. omega. }
    assert (k0:wcbvEval m a1 = Ret a1').
    { rewrite (j m). apply H0. 
      assert (l:= max_snd x (max x0 x1)). assert (l':= max_fst x0 x1).
      omega. omega. }
    simpl. rewrite (j m); try omega.
    rewrite H; try omega. rewrite H0; try omega. rewrite H1; try omega.
    reflexivity.
  - destruct H, H0. exists (S (max x x0)). intros mx h.
    assert (l1:= max_fst x x0). assert (l2:= max_snd x x0).
    simpl. rewrite (j mx); try omega. rewrite (H (mx - 1)); try omega.
    rewrite H0; try omega. reflexivity.
  - destruct H, H0. exists (S (max x0 x1)). intros mx h.
    assert (l1:= max_fst x0 x1). assert (l2:= max_snd x0 x1).
    cbn. rewrite (j mx); try omega. rewrite H; try omega.
    rewrite e. rewrite H0; try omega. reflexivity.
  - destruct H, H0. exists (S (max x x0)). intros mx h.
    assert (l1:= max_fst x x0). assert (l2:= max_snd x x0).
    simpl. rewrite (j mx); try omega. rewrite H; try omega. destruct o.
    + dstrctn H1. subst. rewrite H0; try omega. reflexivity.
    + destruct H1.
      * dstrctn H1. subst. rewrite H0; try omega. reflexivity.
      * dstrctn H1. subst. rewrite H0; try omega. reflexivity.
  - destruct H, H0. exists (S (max x x0)). intros mx h.
    assert (l1:= max_fst x x0). assert (l2:= max_snd x x0).
    simpl. rewrite (j mx); try omega. rewrite H; try omega.    
    rewrite e. rewrite e0. rewrite e1. rewrite (H0 (mx - 1)); try omega.
    reflexivity.
  - destruct H, H0. exists (S (max x x0)). intros mx h.
    assert (l1:= max_fst x x0). assert (l2:= max_snd x x0).
    simpl. rewrite (j mx); try omega. rewrite (H (mx - 1)); try omega.
    rewrite H0; try omega. reflexivity.
Qed.

Lemma WcbvEval_wcbvEval:
  forall t s, WcbvEval p t s ->
             exists n, forall m, m >= n -> wcbvEval m t = Ret s.
Proof.
  intros t s h.
  destruct (proj1 pre_WcbvEval_wcbvEval _ _ h).
  exists (S x). intros m hm. specialize (H (m - 1)).
  assert (k: m = S (m - 1)). { omega. }
  rewrite k. apply H. omega.
Qed.

Lemma wcbvEval_up:
 forall t s tmr,
   wcbvEval tmr t = Ret s ->
   exists n, forall m, m >= n -> wcbvEval m t = Ret s.
Proof.
  intros. destruct (WcbvEval_wcbvEval (proj1 (wcbvEval_WcbvEval _) t s H)).
  exists x. apply H0.
Qed.

End wcbvEval_sec.

