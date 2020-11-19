--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- Copyright (c) 2020 Alexandre Joannou
-- All rights reserved.
--
-- This software was developed by SRI International and the University of
-- Cambridge Computer Laboratory (Department of Computer Science and
-- Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
-- DARPA SSITH research programme.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--

module QuickCheckVEngine.Templates.Utils.HPM (
  setupHPMEventSel
, triggerHPMCounter
, inhibitHPMCounter
, enableHPMCounter
, disableHPMCounter
, readHPMCounter
, writeHPMCounter
, surroundWithHPMAccess
) where

import QuickCheckVEngine.Template
import QuickCheckVEngine.Templates.Utils.General
import RISCV
import Data.Bits
import Test.QuickCheck

-- | Sets up the provided HPM counter to count the provided HPM event
--   (using the provided temporary) 
setupHPMEventSel :: Integer -> HPMEventSelCSRIdx -> HPMEventIdx -> Template
setupHPMEventSel tmpReg sel evt = li32 tmpReg evt <> csrw sel tmpReg

-- | Trigger the provided HPM counter
triggerHPMCounter :: Integer -> HPMCounterIdx -> Template
triggerHPMCounter tmpReg idx = csrBitSetOrClear False mcountinhibit idx tmpReg
  where mcountinhibit = unsafe_csrs_indexFromName "mcountinhibit"

-- | Inhibit the provided HPM counter
inhibitHPMCounter :: Integer -> HPMCounterIdx -> Template
inhibitHPMCounter tmpReg idx = csrBitSetOrClear True mcountinhibit idx tmpReg
  where mcountinhibit = unsafe_csrs_indexFromName "mcountinhibit"

-- | Enable the provided HPM counter's accessibility from less privileged modes
enableHPMCounter :: Integer -> HPMCounterIdx -> Template
enableHPMCounter tmpReg idx = csrBitSetOrClear True mcounteren idx tmpReg
  where mcounteren = unsafe_csrs_indexFromName "mcounteren"

-- | Disable the provided HPM counter's accessibility from less privileged modes
disableHPMCounter :: Integer -> HPMCounterIdx -> Template
disableHPMCounter tmpReg idx = csrBitSetOrClear False mcounteren idx tmpReg
  where mcounteren = unsafe_csrs_indexFromName "mcounteren"

-- | Read the provided HPM counter into the provided destination register
readHPMCounter :: Integer -> HPMCounterIdx -> Template
readHPMCounter rd idx = csrr rd csrIdx 
  where csrIdx = hpmcounter_idx_to_csr_idx idx 

-- | Write the provided general purpose register's value into the provided
--   HPM counter
writeHPMCounter :: HPMCounterIdx -> Integer -> Template
writeHPMCounter idx rs1 = csrw csrIdx rs1
  where csrIdx = hpmcounter_idx_to_csr_idx idx 

-- | 'surroundWithHPMAccess' wraps a 'Template' by setting up an HPM counter to
--   count an event and before running the 'Template' and reading the HPM
--   counter's value after
surroundWithHPMAccess :: Template -> Template
surroundWithHPMAccess x = Random $ do
  evt <- oneof $ map return hpmevent_indices
  return $ surroundWithHPMAccess_core False evt x

-- | inner helper
surroundWithHPMAccess_core :: Bool -> HPMEventIdx -> Template -> Template
surroundWithHPMAccess_core shrink evt x = Random $ do
  hpmCntIdx <- oneof $ map return hpmcounter_indices
  tmpReg <- dest
  let prologue =    inhibitHPMCounter tmpReg hpmCntIdx
                 <> setupHPMEventSel tmpReg hpmCntIdx evt
                 <> writeHPMCounter hpmCntIdx 0
                 <> triggerHPMCounter tmpReg hpmCntIdx
  let epilogue = readHPMCounter tmpReg hpmCntIdx
  return $ if shrink then prologue <> x <> epilogue
                     else NoShrink prologue <> x <> NoShrink epilogue