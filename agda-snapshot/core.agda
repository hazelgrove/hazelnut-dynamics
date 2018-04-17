open import Nat
open import Prelude
open import contexts

module core where
  -- types
  data htyp : Set where
    b     : htyp
    ⦇⦈    : htyp
    _==>_ : htyp → htyp → htyp

  -- arrow type constructors bind very tightly
  infixr 25  _==>_

  -- expressions
  data hexp : Set where
    c       : hexp
    _·:_    : hexp → htyp → hexp
    X       : Nat → hexp
    ·λ      : Nat → hexp → hexp
    ·λ_[_]_ : Nat → htyp → hexp → hexp
    ⦇⦈[_]   : Nat → hexp
    ⦇_⦈[_]  : hexp → Nat → hexp
    _∘_     : hexp → hexp → hexp

  mutual
    subst : Set
    subst = dhexp ctx

    -- expressions without ascriptions but with casts
    data dhexp : Set where
      c        : dhexp
      X        : Nat → dhexp
      ·λ_[_]_  : Nat → htyp → dhexp → dhexp
      ⦇⦈⟨_⟩    : (Nat × subst) → dhexp
      ⦇_⦈⟨_⟩   : dhexp → (Nat × subst) → dhexp
      _∘_      : dhexp → dhexp → dhexp
      _⟨_⇒_⟩   : dhexp → htyp → htyp → dhexp
      _⟨_⇒⦇⦈⇏_⟩   : dhexp → htyp → htyp → dhexp

  -- notation for chaining together agreeable casts
  _⟨_⇒_⇒_⟩ : dhexp → htyp → htyp → htyp → dhexp
  d ⟨ t1 ⇒ t2 ⇒ t3 ⟩ = d ⟨ t1 ⇒ t2 ⟩ ⟨ t2 ⇒ t3 ⟩

  -- type consistency
  data _~_ : (t1 t2 : htyp) → Set where
    TCRefl  : {τ : htyp} → τ ~ τ
    TCHole1 : {τ : htyp} → τ ~ ⦇⦈
    TCHole2 : {τ : htyp} → ⦇⦈ ~ τ
    TCArr   : {τ1 τ2 τ1' τ2' : htyp} →
               τ1 ~ τ1' →
               τ2 ~ τ2' →
               τ1 ==> τ2 ~ τ1' ==> τ2'

  -- type inconsistency
  data _~̸_ : (τ1 τ2 : htyp) → Set where
    ICBaseArr1 : {τ1 τ2 : htyp} → b ~̸ τ1 ==> τ2
    ICBaseArr2 : {τ1 τ2 : htyp} → τ1 ==> τ2 ~̸ b
    ICArr1 : {τ1 τ2 τ3 τ4 : htyp} →
               τ1 ~̸ τ3 →
               τ1 ==> τ2 ~̸ τ3 ==> τ4
    ICArr2 : {τ1 τ2 τ3 τ4 : htyp} →
               τ2 ~̸ τ4 →
               τ1 ==> τ2 ~̸ τ3 ==> τ4

  --- matching for arrows
  data _▸arr_ : htyp → htyp → Set where
    MAHole : ⦇⦈ ▸arr ⦇⦈ ==> ⦇⦈
    MAArr  : {τ1 τ2 : htyp} → τ1 ==> τ2 ▸arr τ1 ==> τ2

  -- aliases for type and hole contexts
  tctx : Set
  tctx = htyp ctx

  hctx : Set
  hctx = (htyp ctx × htyp) ctx

  -- todo: this probably belongs in contexts, but need to abstract it.
  id : tctx → subst
  id ctx x with ctx x
  id ctx x | Some τ = Some (X x)
  id ctx x | None   = None

  -- this is just fancy notation to match the paper
  _::[_]_ : Nat → tctx → htyp → (Nat × (tctx × htyp))
  u ::[ Γ ] τ = u , (Γ , τ)

  postulate
    holes-disjoint : hexp → hexp → Set
    hole-name-new  : hexp → Nat → Set

  -- bidirectional type checking judgements for hexp
  mutual
    -- synthesis
    data _⊢_=>_ : (Γ : tctx) (e : hexp) (τ : htyp) → Set where
      SConst  : {Γ : tctx} → Γ ⊢ c => b
      SAsc    : {Γ : tctx} {e : hexp} {τ : htyp} →
                 Γ ⊢ e <= τ →
                 Γ ⊢ (e ·: τ) => τ
      SVar    : {Γ : tctx} {τ : htyp} {n : Nat} →
                 (n , τ) ∈ Γ →
                 Γ ⊢ X n => τ
      SAp     : {Γ : tctx} {e1 e2 : hexp} {τ τ1 τ2 : htyp} →
                 holes-disjoint e1 e2 → -- need a premise that the hole names are disjoint and something to relate that to the dom(Δ)s in expansion
                 Γ ⊢ e1 => τ1 →
                 τ1 ▸arr τ2 ==> τ →
                 Γ ⊢ e2 <= τ2 →
                 Γ ⊢ (e1 ∘ e2) => τ
      SEHole  : {Γ : tctx} {u : Nat} → Γ ⊢ ⦇⦈[ u ] => ⦇⦈
      SNEHole : {Γ : tctx} {e : hexp} {τ : htyp} {u : Nat} →
                 hole-name-new e u →
                 Γ ⊢ e => τ →   -- premise here that u is disjoint from hole names of e
                 Γ ⊢ ⦇ e ⦈[ u ] => ⦇⦈
      SLam    : {Γ : tctx} {e : hexp} {τ1 τ2 : htyp} {x : Nat} →
                 x # Γ →
                 (Γ ,, (x , τ1)) ⊢ e => τ2 →
                 Γ ⊢ ·λ x [ τ1 ] e => τ1 ==> τ2

    -- analysis
    data _⊢_<=_ : (Γ : htyp ctx) (e : hexp) (τ : htyp) → Set where
      ASubsume : {Γ : tctx} {e : hexp} {τ τ' : htyp} →
                 Γ ⊢ e => τ' →
                 τ ~ τ' →
                 Γ ⊢ e <= τ
      ALam : {Γ : tctx} {e : hexp} {τ τ1 τ2 : htyp} {x : Nat} →
                 x # Γ →
                 τ ▸arr τ1 ==> τ2 →
                 (Γ ,, (x , τ1)) ⊢ e <= τ2 →
                 Γ ⊢ (·λ x e) <= τ

  -- those types without holes anywhere
  data _tcomplete : htyp → Set where
    TCBase : b tcomplete
    TCArr : ∀{τ1 τ2} → τ1 tcomplete → τ2 tcomplete → (τ1 ==> τ2) tcomplete

  -- those expressions without holes anywhere
  data _ecomplete : hexp → Set where
    ECConst : c ecomplete
    ECAsc : ∀{τ e} → τ tcomplete → e ecomplete → (e ·: τ) ecomplete
    ECVar : ∀{x} → (X x) ecomplete
    ECLam1 : ∀{x e} → e ecomplete → (·λ x e) ecomplete
    ECLam2 : ∀{x e τ} → e ecomplete → τ tcomplete → (·λ x [ τ ] e) ecomplete
    ECAp : ∀{e1 e2} → e1 ecomplete → e2 ecomplete → (e1 ∘ e2) ecomplete

  data _dcomplete : dhexp → Set where
    DCVar : ∀{x} → (X x) dcomplete
    DCConst : c dcomplete
    DCLam : ∀{x τ d} → d dcomplete → τ tcomplete → (·λ x [ τ ] d) dcomplete
    DCAp : ∀{d1 d2} → d1 dcomplete → d2 dcomplete → (d1 ∘ d2) dcomplete
    DCCast : ∀{d τ1 τ2} → d dcomplete → τ1 tcomplete → τ2 tcomplete → (d ⟨ τ1 ⇒ τ2 ⟩) dcomplete

  -- contexts that only know about complete types
  _gcomplete : tctx → Set
  Γ gcomplete = (x : Nat) (τ : htyp) → (x , τ) ∈ Γ → τ tcomplete


  -- expansion
  mutual
    data _⊢_⇒_~>_⊣_ : (Γ : tctx) (e : hexp) (τ : htyp) (d : dhexp) (Δ : hctx) → Set where
      ESConst : ∀{Γ} → Γ ⊢ c ⇒ b ~> c ⊣ ∅
      ESVar   : ∀{Γ x τ} → (x , τ) ∈ Γ →
                         Γ ⊢ X x ⇒ τ ~> X x ⊣ ∅
      ESLam   : ∀{Γ x τ1 τ2 e d Δ } →
                     (x # Γ) → -- todo: i added this
                     (Γ ,, (x , τ1)) ⊢ e ⇒ τ2 ~> d ⊣ Δ →
                      Γ ⊢ ·λ x [ τ1 ] e ⇒ (τ1 ==> τ2) ~> ·λ x [ τ1 ] d ⊣ Δ
      ESAp : ∀{Γ e1 τ τ1 τ1' τ2 τ2' d1 Δ1 e2 d2 Δ2 } →
              holes-disjoint e1 e2 →
              Δ1 ## Δ2 →
              Γ ⊢ e1 => τ1 →
              τ1 ▸arr τ2 ==> τ →
              Γ ⊢ e1 ⇐ (τ2 ==> τ) ~> d1 :: τ1' ⊣ Δ1 →
              Γ ⊢ e2 ⇐ τ2 ~> d2 :: τ2' ⊣ Δ2 →
              Γ ⊢ e1 ∘ e2 ⇒ τ ~> (d1 ⟨ τ1' ⇒ τ2 ==> τ ⟩) ∘ (d2 ⟨ τ2' ⇒ τ2 ⟩) ⊣ (Δ1 ∪ Δ2)
      ESEHole : ∀{ Γ u } →
                Γ ⊢ ⦇⦈[ u ] ⇒ ⦇⦈ ~> ⦇⦈⟨ u , id Γ ⟩ ⊣  ■ (u ::[ Γ ] ⦇⦈)
      ESNEHole : ∀{ Γ e τ d u Δ } →
                 Δ ## (■ (u , Γ , ⦇⦈)) →
                 Γ ⊢ e ⇒ τ ~> d ⊣ Δ →
                 Γ ⊢ ⦇ e ⦈[ u ] ⇒ ⦇⦈ ~> ⦇ d ⦈⟨ u , id Γ  ⟩ ⊣ (Δ ,, u ::[ Γ ] ⦇⦈)
      ESAsc : ∀ {Γ e τ d τ' Δ} →
                 Γ ⊢ e ⇐ τ ~> d :: τ' ⊣ Δ →
                 Γ ⊢ (e ·: τ) ⇒ τ ~> d ⟨ τ' ⇒ τ ⟩ ⊣ Δ

    data _⊢_⇐_~>_::_⊣_ : (Γ : tctx) (e : hexp) (τ : htyp) (d : dhexp) (τ' : htyp) (Δ : hctx) → Set where
      EALam : ∀{Γ x τ τ1 τ2 e d τ2' Δ } →
              (x # Γ) →
              τ ▸arr τ1 ==> τ2 →
              (Γ ,, (x , τ1)) ⊢ e ⇐ τ2 ~> d :: τ2' ⊣ Δ →
              Γ ⊢ ·λ x e ⇐ τ ~> ·λ x [ τ1 ] d :: τ1 ==> τ2' ⊣ Δ
      EASubsume : ∀{e Γ τ' d Δ τ} →
                  ((u : Nat) → e ≠ ⦇⦈[ u ]) →
                  ((e' : hexp) (u : Nat) → e ≠ ⦇ e' ⦈[ u ]) →
                  Γ ⊢ e ⇒ τ' ~> d ⊣ Δ →
                  τ ~ τ' →
                  Γ ⊢ e ⇐ τ ~> d :: τ' ⊣ Δ
      EAEHole : ∀{ Γ u τ  } →
                Γ ⊢ ⦇⦈[ u ] ⇐ τ ~> ⦇⦈⟨ u , id Γ  ⟩ :: τ ⊣ ■ (u ::[ Γ ] τ)
      EANEHole : ∀{ Γ e u τ d τ' Δ  } →
                 Δ ## (■ (u , Γ , τ)) →
                 Γ ⊢ e ⇒ τ' ~> d ⊣ Δ →
                 Γ ⊢ ⦇ e ⦈[ u ] ⇐ τ ~> ⦇ d ⦈⟨ u , id Γ  ⟩ :: τ ⊣ (Δ ,, u ::[ Γ ] τ)

  -- ground
  data _ground : (τ : htyp) → Set where
    GBase : b ground
    GHole : ⦇⦈ ==> ⦇⦈ ground

  mutual
    -- substitition type assignment
    _,_⊢_:s:_ : hctx → tctx → subst → tctx → Set
    Δ , Γ ⊢ σ :s: Γ' =
        (x : Nat) (d : dhexp) (xd∈σ : (x , d) ∈ σ) →
            Σ[ τ ∈ htyp ] ((Γ' x == Some τ × (Δ , Γ ⊢ d :: τ)))

    -- type assignment
    data _,_⊢_::_ : (Δ : hctx) (Γ : tctx) (d : dhexp) (τ : htyp) → Set where
      TAConst : ∀{Δ Γ} → Δ , Γ ⊢ c :: b
      TAVar : ∀{Δ Γ x τ} → (x , τ) ∈ Γ → Δ , Γ ⊢ X x :: τ
      TALam : ∀{ Δ Γ x τ1 d τ2} →
              Δ , (Γ ,, (x , τ1)) ⊢ d :: τ2 →
              Δ , Γ ⊢ ·λ x [ τ1 ] d :: (τ1 ==> τ2)
      TAAp : ∀{ Δ Γ d1 d2 τ1 τ} →
             Δ , Γ ⊢ d1 :: τ1 ==> τ →
             Δ , Γ ⊢ d2 :: τ1 →
             Δ , Γ ⊢ d1 ∘ d2 :: τ
      TAEHole : ∀{ Δ Γ σ u Γ' τ} →
                (u , (Γ' , τ)) ∈ Δ →
                Δ , Γ ⊢ σ :s: Γ' →
                Δ , Γ ⊢ ⦇⦈⟨ u , σ ⟩ :: τ
      TANEHole : ∀ { Δ Γ d τ' Γ' u σ τ } →
                 (u , (Γ' , τ)) ∈ Δ →
                 Δ , Γ ⊢ d :: τ' →
                 Δ , Γ ⊢ σ :s: Γ' →
                 Δ , Γ ⊢ ⦇ d ⦈⟨ u , σ ⟩ :: τ
      TACast : ∀{ Δ Γ d τ1 τ2} →
             Δ , Γ ⊢ d :: τ1 →
             τ1 ~ τ2 →
             Δ , Γ ⊢ d ⟨ τ1 ⇒ τ2 ⟩ :: τ2
      TAFailedCast : ∀{Δ Γ d τ1 τ2} →
             Δ , Γ ⊢ d :: τ1 →
             τ1 ground →
             τ2 ground →
             τ1 ≠ τ2 →
             Δ , Γ ⊢ d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩ :: τ2

  -- substitution;; todo: maybe get a premise that it's final; analagous to "value substitution"
  [_/_]_ : dhexp → Nat → dhexp → dhexp
  [ d / y ] c = c
  [ d / y ] X x
    with natEQ x y
  [ d / y ] X .y | Inl refl = d
  [ d / y ] X x  | Inr neq = X x
  [ d / y ] (·λ x [ x₁ ] d') = ·λ x [ x₁ ] ( [ d / y ] d') -- TODO: i *think* barendrecht's saves us here, or at least i want it to. may need to reformulat this as a relation --> set
  [ d / y ] ⦇⦈⟨ u , σ ⟩ = ⦇⦈⟨ u , σ ⟩
  [ d / y ] ⦇ d' ⦈⟨ u , σ  ⟩ =  ⦇ [ d / y ] d' ⦈⟨ u , σ ⟩
  [ d / y ] (d1 ∘ d2) = ([ d / y ] d1) ∘ ([ d / y ] d2)
  [ d / y ] (d' ⟨ τ1 ⇒ τ2 ⟩ ) = ([ d / y ] d') ⟨ τ1 ⇒ τ2 ⟩
  [ d / y ] (d' ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩ ) = ([ d / y ] d') ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩

  -- value
  data _val : (d : dhexp) → Set where
    VConst : c val
    VLam   : ∀{x τ d} → (·λ x [ τ ] d) val

  data _boxedval : (d : dhexp) → Set where
    BVVal : ∀{d} → d val → d boxedval
    BVArrCast : ∀{ d τ1 τ2 τ3 τ4 } →
                τ1 ==> τ2 ≠ τ3 ==> τ4 →
                d boxedval →
                d ⟨ (τ1 ==> τ2) ⇒ (τ3 ==> τ4) ⟩ boxedval
    BVHoleCast : ∀{ τ d } → τ ground → d boxedval → d ⟨ τ ⇒ ⦇⦈ ⟩ boxedval

  mutual
    -- indeterminate
    data _indet : (d : dhexp) → Set where
      IEHole : ∀{u σ} → ⦇⦈⟨ u , σ ⟩ indet
      INEHole : ∀{d u σ} → d final → ⦇ d ⦈⟨ u , σ ⟩ indet
      IAp : ∀{d1 d2} → ((τ1 τ2 τ3 τ4 : htyp) (d1' : dhexp) →
                       d1 ≠ (d1' ⟨(τ1 ==> τ2) ⇒ (τ3 ==> τ4)⟩)) →
                       d1 indet →
                       d2 final →
                       (d1 ∘ d2) indet
      ICastArr : ∀{d τ1 τ2 τ3 τ4} →
                 τ1 ==> τ2 ≠ τ3 ==> τ4 →
                 d indet →
                 d ⟨ (τ1 ==> τ2) ⇒ (τ3 ==> τ4) ⟩ indet
      ICastGroundHole : ∀{ τ d } →
                        τ ground →
                        d indet →
                        d ⟨ τ ⇒  ⦇⦈ ⟩ indet
      ICastHoleGround : ∀ { d τ } →
                        ((d' : dhexp) (τ' : htyp) → d ≠ (d' ⟨ τ' ⇒ ⦇⦈ ⟩)) →
                        d indet →
                        τ ground →
                        d ⟨ ⦇⦈ ⇒ τ ⟩ indet
      IFailedCast : ∀{ d τ1 τ2 } →
                    d final →
                    τ1 ground →
                    τ2 ground →
                    τ1 ≠ τ2 →
                    d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩ indet

    -- final
    data _final : (d : dhexp) → Set where
      FBoxed : ∀{d} → d boxedval → d final
      FIndet : ∀{d} → d indet → d final


  -- contextual dynamics

  -- evaluation contexts
  data ectx : Set where
    ⊙ : ectx
    _∘₁_ : ectx → dhexp → ectx
    _∘₂_ : dhexp → ectx → ectx
    ⦇_⦈⟨_⟩ : ectx → (Nat × subst ) → ectx
    _⟨_⇒_⟩ : ectx → htyp → htyp → ectx
    _⟨_⇒⦇⦈⇏_⟩ : ectx → htyp → htyp → ectx

 -- todo/ note: this judgement is redundant now; in the absence of the
 -- premises in the red brackets in the notes PDF, all syntactically well
 -- formed ectxs are valid; with finality premises, that's not true. so it
 -- might make sense to remove this judgement entirely, but need to make
 -- sure to describe why we don't have the redbox things and how we'd patch
 -- it up if we wanted to force a particular evaluation order in some
 -- document somewhere (probably a README for this repo, or a sentence in
 -- the paper text or both)

 --ε is an evaluation context
  data _evalctx : (ε : ectx) → Set where
    ECDot : ⊙ evalctx
    ECAp1 : ∀{d ε} →
            ε evalctx →
            (ε ∘₁ d) evalctx
    ECAp2 : ∀{d ε} →
            -- d final → -- red box
            ε evalctx →
            (d ∘₂ ε) evalctx
    ECNEHole : ∀{ε u σ} →
               ε evalctx →
               ⦇ ε ⦈⟨ u , σ ⟩ evalctx
    ECCast : ∀{ ε τ1 τ2} →
             ε evalctx →
             (ε ⟨ τ1 ⇒ τ2 ⟩) evalctx
    ECFailedCast : ∀{ ε τ1 τ2 } →
                   ε evalctx →
                   ε ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩ evalctx

  -- d is the result of filling the hole in ε with d'
  data _==_⟦_⟧ : (d : dhexp) (ε : ectx) (d' : dhexp) → Set where
    FHOuter : ∀{d} → d == ⊙ ⟦ d ⟧
    FHAp1 : ∀{d1 d1' d2 ε} →
           d1 == ε ⟦ d1' ⟧ →
           (d1 ∘ d2) == (ε ∘₁ d2) ⟦ d1' ⟧
    FHAp2 : ∀{d1 d2 d2' ε} →
           -- d1 final → -- red box
           d2 == ε ⟦ d2' ⟧ →
           (d1 ∘ d2) == (d1 ∘₂ ε) ⟦ d2' ⟧
    FHNEHole : ∀{ d d' ε u σ} →
              d == ε ⟦ d' ⟧ →
              ⦇ d ⦈⟨ (u , σ ) ⟩ ==  ⦇ ε ⦈⟨ (u , σ ) ⟩ ⟦ d' ⟧
    FHCast : ∀{ d d' ε τ1 τ2 } →
            d == ε ⟦ d' ⟧ →
            d ⟨ τ1 ⇒ τ2 ⟩ == ε ⟨ τ1 ⇒ τ2 ⟩ ⟦ d' ⟧
    FHFailedCast : ∀{ d d' ε τ1 τ2} →
            d == ε ⟦ d' ⟧ →
            (d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩) == (ε ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩) ⟦ d' ⟧

  data _▸gnd_ : htyp → htyp → Set where
    MGArr : ∀{τ1 τ2} →
            (τ1 ==> τ2) ≠ (⦇⦈ ==> ⦇⦈) →
            (τ1 ==> τ2) ▸gnd (⦇⦈ ==> ⦇⦈)

  -- instruction transition judgement
  data _→>_ : (d d' : dhexp) → Set where
    ITLam : ∀{ x τ d1 d2 } →
            -- d2 final → -- red box
            ((·λ x [ τ ] d1) ∘ d2) →> ([ d2 / x ] d1)
    ITCastID : ∀{d τ } →
               -- d final → -- red box
               (d ⟨ τ ⇒ τ ⟩) →> d
    ITCastSucceed : ∀{d τ } →
                    -- d final → -- red box
                    τ ground →
                    (d ⟨ τ ⇒ ⦇⦈ ⇒ τ ⟩) →> d
    ITCastFail : ∀{ d τ1 τ2} →
                 -- d final → -- red box
                 τ1 ground →
                 τ2 ground →
                 τ1 ≠ τ2 →
                 (d ⟨ τ1 ⇒ ⦇⦈ ⇒ τ2 ⟩) →> (d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩)
    ITApCast : ∀{d1 d2 τ1 τ2 τ1' τ2' } →
               -- d1 final → -- red box
               -- d2 final → -- red box
               ((d1 ⟨ (τ1 ==> τ2) ⇒ (τ1' ==> τ2')⟩) ∘ d2) →> ((d1 ∘ (d2 ⟨ τ1' ⇒ τ1 ⟩)) ⟨ τ2 ⇒ τ2' ⟩)
    ITGround : ∀{ d τ τ'} →
               -- d final → -- red box
               τ ▸gnd τ' →
               (d ⟨ τ ⇒ ⦇⦈ ⟩) →> (d ⟨ τ ⇒ τ' ⇒ ⦇⦈ ⟩)
    ITExpand : ∀{d τ τ' } →
               -- d final → -- red box
               τ ▸gnd τ' →
               (d ⟨ ⦇⦈ ⇒ τ ⟩) →> (d ⟨ ⦇⦈ ⇒ τ' ⇒ τ ⟩)

  data _↦_ : (d d' : dhexp) → Set where
    Step : ∀{ d d0 d' d0' ε} →
           d == ε ⟦ d0 ⟧ →
           d0 →> d0' →
           d' == ε ⟦ d0' ⟧ →
           d ↦ d'

  data _↦*_ : (d d' : dhexp) → Set where
    MSRefl : ∀{d} → d ↦* d
    MSStep : ∀{d d' d''} →
                 d ↦ d' →
                 d' ↦* d'' →
                 d  ↦* d''

  -- application of a substution to a term
  -- todo: this is not well-founded with the current representation of σs
  postulate
    apply : subst → dhexp → dhexp
  -- apply σ c = c
  -- apply σ (X x) with σ x
  -- apply σ (X x) | Some d' = d'
  -- apply σ (X x) | None = X x
  -- apply σ (·λ x [ τ ] d) = (·λ x [ τ ] (apply σ d))
  -- apply σ ⦇⦈⟨ u , σ' ⟩ =  ⦇⦈⟨ u , ((λ x → (lift (apply σ)) (σ' x))) ⟩ -- (λ x → (lift (apply σ)) (σ' x))
  -- apply σ ⦇ d ⦈⟨ u , σ' ⟩ = ⦇ apply σ d ⦈⟨ u ,{!!} ⟩
  -- apply σ (d1 ∘ d2) = ((apply σ d1) ∘ (apply σ d2))
  -- apply σ (d ⟨ τ1 ⇒ τ2 ⟩) = ((apply σ d) ⟨ τ1 ⇒ τ2 ⟩)
  -- apply σ (d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩) = ((apply σ d) ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩)

  --hole instantiation; todo: judgemental or functional?
  ⟦_/_⟧_ : dhexp → Nat → dhexp → dhexp
  ⟦ d / u ⟧ c = c
  ⟦ d / u ⟧ X x = X x
  ⟦ d / u ⟧ (·λ x [ τ ] d') = ·λ x [ τ ] (⟦ d / u ⟧ d')
  ⟦ d / u ⟧ ⦇⦈⟨ n , σ ⟩
    with natEQ n u
  ⟦ d / u ⟧ ⦇⦈⟨ .u , σ ⟩ | Inl refl = apply σ d
  ⟦ d / u ⟧ ⦇⦈⟨ n , σ ⟩  | Inr x = ⦇⦈⟨ n , σ ⟩
  ⟦ d / u ⟧ ⦇ d' ⦈⟨ n , σ ⟩
    with natEQ n u
  ⟦ d / u ⟧ ⦇ d' ⦈⟨ .u , σ ⟩ | Inl refl = apply σ d
  ⟦ d / u ⟧ ⦇ d' ⦈⟨ n , σ ⟩ | Inr x = ⦇ d' ⦈⟨ n , σ ⟩
  ⟦ d / u ⟧ (d1 ∘ d2) = (⟦ d / u ⟧ d1) ∘ (⟦ d / u ⟧ d2)
  ⟦ d / u ⟧ (d' ⟨ τ1 ⇒ τ2 ⟩) = (⟦ d / u ⟧ d') ⟨ τ1 ⇒ τ2 ⟩
  ⟦ d / u ⟧ (d' ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩) = (⟦ d / u ⟧ d') ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩
