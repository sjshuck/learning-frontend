{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ViewPatterns #-}

module Main (
    main)
where

import           Conduit              ((.|), foldC, runConduit)
import           Data.HashMap.Strict  (HashMap)
import qualified Data.HashMap.Strict  as HM
import           Data.IORef
import           Data.Text            (Text)
import qualified Data.Text            as Text
import qualified Data.Text.Encoding   as Text
import           Yesod.Core
import           Yesod.Core.Types     (JSONResponse(..))
import           Yesod.EmbeddedStatic

mkEmbeddedStatic False "embeddedStatic" [embedDir "assets"]

data MapService = MapService{
    mapServiceMapRef         :: IORef (HashMap Text Text),
    mapServiceEmbeddedStatic :: EmbeddedStatic}

mkYesod "MapService" [parseRoutes|
    /            RootR        GET
    /healthcheck HealthCheckR GET
    /key/#Text   KeyR         GET PUT DELETE
    /static      StaticR      EmbeddedStatic mapServiceEmbeddedStatic
|]

instance Yesod MapService

getRootR :: Handler Html
getRootR = [hamlet|
    $doctype 5
    <html>
        <head>
            <title> Map Service
            <link rel=stylesheet href=@{StaticR map_service_css}>
            <script src=@{StaticR map_service_js} defer>
            <script defer>
                fetch('@{StaticR map_service_html}')
                    .then(resp => resp.text())
                    .then(body => {
                        document.body.innerHTML = body;
                        init();
                    });
        <body>
|] <$> getUrlRenderParams

getHealthCheckR :: Handler Text
getHealthCheckR = return "OK"

getKeyR :: Text -> Handler Text
getKeyR k = do
    kvs <- getsYesod mapServiceMapRef >>= liftIO . readIORef
    maybe notFound return $ HM.lookup k kvs

newtype Previous = Previous (Maybe Text)
instance ToJSON Previous where
    toJSON (Previous maybeV) = object ["previous" .= maybeV]

replaceAtKey :: Text -> Maybe Text -> Handler (Maybe Text)
replaceAtKey k maybeV = do
    ref <- getsYesod mapServiceMapRef
    liftIO $ atomicModifyIORef' ref $ \kvs ->
        let (maybePrev, kvs') = HM.alterF (, maybeV) k kvs
        in (kvs', maybePrev)

putKeyR :: Text -> Handler (JSONResponse Previous)
putKeyR k = do
    reqBody <- runConduit $ rawRequestBody .| foldC
    case Text.decodeUtf8' reqBody of
        Left e  -> invalidArgs [Text.pack $ show e]
        Right v -> JSONResponse . Previous <$> replaceAtKey k (Just v)

deleteKeyR :: Text -> Handler (JSONResponse Previous)
deleteKeyR k = do
    maybePrev <- replaceAtKey k Nothing
    maybe notFound (return . JSONResponse . Previous . Just) maybePrev

main :: IO ()
main = do
    mapServiceMapRef <- newIORef HM.empty
    warp 3000 MapService{mapServiceEmbeddedStatic = embeddedStatic, ..}
