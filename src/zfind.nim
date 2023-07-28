import os
import parseopt
import streams
import strutils
import pegs
import zip/libzip

type
  FileNotFound = object of ValueError


const
  helpText = """
  zfind finds files by name in a given zip file, jar file, war file.
  Also supports name patterns specified in the Nim PEG notation.
  Usage
    zfind -p:<name pattern> <zip file name>
    zfind -P:<pattern file name> <zip file name>

  """
  NIL = ""
  cPegsDirKey = "PEGS_DIR"
  cPegsDir = "pegs"


var patternPeg: Peg
var pegFile: string
var zipFile: string
var showHelp = false


proc stdPegsDir(): string =
  joinPath(getAppDir(), cPegsDir)

proc readPatternFile(filePath: string): string =
  assert(filePath != NIL)
  if fileExists(absolutePath(filePath)):
    result = system.readFile(absolutePath(filePath))
  else:
    let pegsDir = getEnv(cPegsDirKey, stdPegsDir())
    let stdPatFile = joinPath(pegsDir, filePath)
    if fileExists stdPatFile:
      result = system.readFile(stdPatFile)
    else:
      raise newException(FileNotFound, "File not found: '$#'" % [filePath])


proc findEntries(path: string, pattern: Peg) =
  var err: int32
  var pzip: PZip = zip_open(path, 0, addr err)
  if (pzip == nil):
    echo "Could not open file: ", err
  else:
    var entries = zip_get_num_files(pzip)
    # mark the block that I want to be able to exit
    block processing:
      for i in countup(0, entries-1):
        var entryname = zip_get_name(pzip, int32(i), 0)
        if $entryname =~ pattern:
          echo entryname
        else: discard
    zip_close(pzip)


for kind, key, val in getopt():
  case kind
  of cmdArgument:
    zipFile = key
  of cmdLongOption, cmdShortOption:
    case key
    of "peg", "p": patternPeg = peg(val)
    of "pegfile", "P": patternPeg = peg(readPatternFile(val))
    of "help", "h": showHelp = true
    else: discard
  of cmdEnd: assert(false) # cannot happen
  else: discard

if showHelp:
  echo helpText
else:
  findEntries(zipFile, patternPeg)