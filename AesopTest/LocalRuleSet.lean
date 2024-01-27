/-
Copyright (c) 2022 Jannis Limperg. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jannis Limperg
-/

import Aesop
import Std.Tactic.GuardMsgs

set_option aesop.check.all true
set_option aesop.smallErrorMessages true

-- We used to add local rules to the `default` rule set, but this doesn't work
-- well when the default rule set is disabled.

/--
error: tactic 'aesop' failed, failed to prove the goal after exhaustive search.
-/
#guard_msgs in
example : Unit := by
  aesop (rule_sets [-default, -builtin]) (config := { terminal := true })

example : Unit := by
  aesop (add safe PUnit.unit) (rule_sets [-default, -builtin])
