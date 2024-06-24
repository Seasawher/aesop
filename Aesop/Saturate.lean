/-
Copyright (c) 2024 Jannis Limperg. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jannis Limperg
-/

import Aesop.Builder.Forward
import Aesop.RuleSet
import Aesop.RuleTac
import Aesop.Search.Expansion.Basic

open Lean Lean.Meta

namespace Aesop

-- TODO mv
def RuleName.isForwardOrDestruct (n : RuleName) : Bool :=
  n.builder == .forward || n.builder == .destruct

structure ForwardM.Context where
  options : Aesop.Options'

abbrev ForwardM := ReaderT ForwardM.Context MetaM

-- TODO mv?
def RuleTacOutput.getSingleGoal [Monad m] [MonadError m] (o : RuleTacOutput) :
    m (MVarId × Meta.SavedState) := do
  let #[app] := o.applications
    | throwError "rule produced more than one rule application"
  let #[goal] := app.goals
    | throwError "rule did not produce exactly one subgoal"
  return (goal, app.postState)

initialize
  registerTraceClass `saturate

-- TODO exc prefixes
partial def saturate (rs : LocalRuleSet) (goal : MVarId) : ForwardM MVarId := do
  goal.checkNotAssigned `saturate
  go goal
where
  go (goal : MVarId) : ForwardM MVarId :=
    withIncRecDepth do
    trace[saturate] "goal:{indentD goal}"
    let matchResults ← rs.applicableSafeRulesWith goal
      (include? := (·.name.isForwardOrDestruct))
    let mvars := UnorderedArraySet.ofHashSet $ ← goal.getMVarDependencies
    let preState ← show MetaM _ from saveState
    for matchResult in matchResults do
      trace[saturate] "running rule {matchResult.rule.name}"
      let input := {
        indexMatchLocations := matchResult.locations
        patternInstantiations := matchResult.patternInstantiations
        options := (← read).options
        goal, mvars
      }
      let tacResult ←
        runRuleTac matchResult.rule.tac.run matchResult.rule.name preState input
      match tacResult with
      | .inl exc =>
        trace[saturate] "rule failed:{indentD exc.toMessageData}"
        continue
      | .inr output =>
        let (goal, postState) ← output.getSingleGoal
        postState.restore
        return ← go goal
    clearForwardImplDetailHyps goal

end Aesop
