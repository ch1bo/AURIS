module Data.Conversion.TMPacket
  ( convertPacket
  )
where

import           RIO
import qualified RIO.HashMap                   as HM
import qualified RIO.List                      as L
--import           Data.Text.Short                ( ShortText )

import           Data.MIB.PID
import           Data.MIB.TPCF
import           Data.MIB.PLF

import           Data.TM.TMPacketDef

import           General.PUSTypes
import           General.TriState
import           General.APID

import           Data.Conversion.Types



convertPacket
  :: HashMap Word32 TPCFentry
  -> Vector PLFentry
  -> PIDentry
  -> TriState Text Text (Warnings, TMPacketDef)
convertPacket tpcfs plfs pid@PIDentry {..} =
  let params = if _pidTPSD == -1 then getFixedParams else getVariableParams
  in  createPacket pid (HM.lookup _pidSPID tpcfs) params

 where
  createPacket PIDentry {..} tpcf params =
    let name = case tpcf of
          Just TPCFentry {..} -> _tpcfName
          Nothing             -> ""
    in  TOk
          ( Nothing
          , TMPacketDef { _tmpdSPID    = SPID _pidSPID
                        , _tmpdName    = name
                        , _tmpdType    = mkPUSType (fromIntegral _pidType)
                        , _tmpdSubType = mkPUSSubType (fromIntegral _pidSubType)
                        , _tmpdApid    = APID (fromIntegral _pidAPID)
                        , _tmpdPI1Val  = _pidP1Val
                        , _tmpdPI2Val  = _pidP2Val
                        , _tmpdParams  = params
                        }
          )

  getFixedParams =
    let pls = L.sort . filter (\x -> _pidSPID == _plfSPID x) . toList $ plfs
    in  undefined


  getVariableParams = undefined