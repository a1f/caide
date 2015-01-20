{-# LANGUAGE OverloadedStrings #-}
{- | Common utilities
-}
module Caide.Util (
      downloadDocument
    , getProblemID
    , pathToText
    , tshow
    , forceEither
    , listDir
    , copyFileToDir
    , copyTreeToDir
    , splitString
    , trimString
) where

import Control.Monad (forM_)
import Data.Char (isSpace)
import Data.Maybe (fromJust)
import qualified Data.Text as T
import Filesystem (copyFile, listDirectory, isFile, isDirectory, createDirectory)
import qualified Filesystem.Path as F
import Filesystem.Path (basename, filename, (</>))
import Filesystem.Path.CurrentOS (toText)
import Network.HTTP
import Network.URI (parseURI)
import System.IO.Error (catchIOError, ioeGetErrorString)

import Caide.Types (ProblemID, URL)


{- | Download a URL. Return (Left errorMessage) in case of an error,
(Right doc) in case of success.
Based on code snippet from 'Real World Haskell'.
-}
-- TODO: retry download if anything wrong
downloadDocument :: URL -> IO (Either T.Text T.Text)
downloadDocument url
    | "http" `T.isPrefixOf` url  =  result
    | otherwise = mkLiftedError "Not implemented"
  where
    mkLiftedError = return . Left
    result = downloader `catchIOError` (mkLiftedError . T.pack . ioeGetErrorString)
    downloader :: IO (Either T.Text T.Text)
    downloader = do
        let request = Request {rqURI = fromJust . parseURI $ T.unpack url,
                               rqMethod = GET,
                               rqHeaders = [],
                               rqBody = ""}

        resp <- simpleHTTP request
        case resp of
            Left x  -> mkLiftedError $ T.concat ["Error connecting: ", tshow x]
            Right r -> case rspCode r of
                (2,_,_) -> return . Right . T.pack $ rspBody r
                (3,_,_) -> -- An HTTP redirect
                    case findHeader HdrLocation r of
                        Nothing   -> mkLiftedError $ tshow r
                        -- FIXME: avoid infinite recursion
                        Just url' -> downloadDocument $ T.pack url'
                _ -> mkLiftedError $ tshow r

tshow :: Show a => a -> T.Text
tshow = T.pack . show

pathToText :: F.FilePath -> T.Text
pathToText path = case toText path of
    Left  s -> s
    Right s -> s

getProblemID :: F.FilePath -> ProblemID
getProblemID = pathToText . basename

forceEither :: Either a c -> c
forceEither = either (error "Left in forceEither") id

-- | Returns (file list, directory list)
listDir :: F.FilePath -> IO ([F.FilePath], [F.FilePath])
listDir dir = do
    filesAndDirs <- listDirectory dir
    thisIsFile <- mapM isFile filesAndDirs
    thisIsDir <- mapM isDirectory filesAndDirs
    let files = map fst . filter snd $ zip filesAndDirs thisIsFile
        dirs  = map fst . filter snd $ zip filesAndDirs thisIsDir
    return (files, dirs)

copyFileToDir :: F.FilePath -> F.FilePath -> IO ()
copyFileToDir srcFile dstDir = copyFile srcFile dstFile
    where dstFile = dstDir </> filename srcFile

copyTreeToDir :: F.FilePath -> F.FilePath -> IO ()
copyTreeToDir srcTree dstDir = do
    let targetDir = dstDir </> basename srcTree
    createDirectory True targetDir
    (files, dirs) <- listDir srcTree
    forM_ files $ \file -> copyFileToDir file targetDir
    forM_ dirs $ \dir -> copyTreeToDir dir targetDir


splitString :: String -> String -> [String]
splitString separators s = reverse (go s []) where
    go [] parts = parts
    go str parts = let (_, rest)     = span (`elem` separators) str
                       (word, rest') = break (`elem` separators) rest
                   in go rest' $ if null word then parts else word:parts

trimString :: String -> String
trimString = reverse . dropWhile isSpace . reverse . dropWhile isSpace
