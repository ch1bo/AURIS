{-# LANGUAGE
    OverloadedStrings
    , BangPatterns
    , NoImplicitPrelude
#-}
module Main where


import           RIO
import qualified RIO.ByteString                as B
import qualified RIO.Text                      as T
import qualified Data.Text.IO                  as T
import           RIO.List

import           Control.Lens                   ( (.~) )

import           Data.PUS.TMFrame
import           Data.PUS.TMFrameExtractor
import           Data.PUS.Config
import           Data.PUS.MissionSpecific.Definitions
import           Data.PUS.ExtractedDU
import           Data.PUS.Types
import           Data.PUS.GlobalState

import           General.Types
import           General.Chunks

import           Conduit
import qualified Data.Conduit.List             as C

import           Protocol.ProtocolInterfaces

import           Test.Hspec





makeTMFrames
    :: Config -> PUSMissionSpecific -> TMFrameHeader -> ByteString -> [TMFrame]
makeTMFrames cfg missionSpecific hdr pl =
    let len       = tmFrameMaxDataLen cfg missionSpecific hdr
        frameData = chunkedByBS len pl
        hdrs      = map upd [0 ..]
        upd x = hdr & tmFrameVCFC .~ x & tmFrameMCFC .~ x
        frames = zipWith makeTMFrame hdrs frameData
    in  frames


runTestAction :: RIO GlobalState b -> IO b
runTestAction action = do
    defLogOptions <- logOptionsHandle stdout True
    let logOptions = setLogMinLevel LevelError defLogOptions
    withLogFunc logOptions $ \logFunc -> do
        state <- newGlobalState
                    defaultConfig
                    defaultMissionSpecific
                    logFunc
                    (\ev -> T.putStrLn ("Event: " <> T.pack (show ev)))

        runRIO state action

goodExtraction :: Config -> IO ()
goodExtraction cfg = do
    let payload = B.pack (take 4096 (cycle [0 .. 255]))
    let frames = map ep $ makeTMFrames cfg
                    defaultMissionSpecific
                    tmFrameDefaultHeader
                    payload
        ep x = ExtractedDU { _epQuality = toFlag Good True
                        , _epGap     = Nothing
                        , _epSource  = IF_NCTRS
                        , _epDU      = x
                        }
        conduit =C.sourceList frames
                .| extractPktFromTMFramesC defaultMissionSpecific
                        IF_NCTRS
                .| C.consume
    result <- runTestAction (runConduit conduit)

    length result `shouldBe` 3
    B.concat result `shouldBe` payload
    return ()


main :: IO ()
main = hspec $ do
    let cfg = defaultConfig

    describe "TM Frame Extraction" $ do
        it "good extraction" $ do
            goodExtraction cfg

