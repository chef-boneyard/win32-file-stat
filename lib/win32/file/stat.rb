require 'ffi'

class File::Stat
  extend FFI::Library
  ffi_lib :kernel32

  private

  attach_function :FindFirstFile, :FindFirstFileW, [:buffer_in, :pointer], :ulong
  attach_function :FindNextFile, :FindNextFileW, [:buffer_in, :pointer], :bool
  attach_function :FindClose, [:ulong], :bool
  attach_function :GetDiskFreeSpace, :GetDiskFreeSpaceW, [:buffer_in, :pointer, :pointer, :pointer, :pointer], :bool

  ffi_lib :shlwapi

  attach_function :PathStripToRoot, :PathStripToRootW, [:pointer], :bool

  MAX_PATH = 260

  class LowHigh < FFI::Struct
    layout(:LowPart, :ulong, :HighPart, :ulong)
  end

  class ULARGE_INTEGER < FFI::Union
    layout(:u, LowHigh, :QuadPart, :ulong_long)
  end

  class FILETIME < FFI::Struct
    layout(:dwLowDateTime, :ulong, :dwHighDateTime, :ulong)
  end

  class WIN32_FIND_DATA < FFI::Struct
    layout(
      :dwFileAttributes, :ulong,
      :ftCreationTime, FILETIME,
      :ftLastAccessTime, FILETIME,
      :ftLastWriteTime, FILETIME,
      :nFileSizeHigh, :ulong,
      :nFileSizeLow, :ulong,
      :dwReserved0, :ulong,
      :dwReserved1, :ulong,
      :cFileName, [:uint8, MAX_PATH],
      :cAlternateFileName, [:uint8, 14]
    )

    # Return the atime as a number
    def atime
      date = ULARGE_INTEGER.new
      date[:u][:LowPart] = self[:ftLastAccessTime][:dwLowDateTime]
      date[:u][:HighPart] = self[:ftLastAccessTime][:dwHighDateTime]
      date[:QuadPart] / 10000000 - 11644473600 # ns, 100-ns since Jan 1, 1601.
    end

    # Return the ctime as a number
    def ctime
      date = ULARGE_INTEGER.new
      date[:u][:LowPart] = self[:ftCreationTime][:dwLowDateTime]
      date[:u][:HighPart] = self[:ftCreationTime][:dwHighDateTime]
      date[:QuadPart] / 10000000 - 11644473600 # ns, 100-ns since Jan 1, 1601.
    end

    # Return the mtime as a number
    def mtime
      date = ULARGE_INTEGER.new
      date[:u][:LowPart] = self[:ftLastWriteTime][:dwLowDateTime]
      date[:u][:HighPart] = self[:ftLastWriteTime][:dwHighDateTime]
      date[:QuadPart] / 10000000 - 11644473600 # ns, 100-ns since Jan 1, 1601.
    end
  end

  INVALID_HANDLE_VALUE = 0xFFFFFFFF
  ERROR_FILE_NOT_FOUND = 2

  FILE_TYPE_UNKNOWN = 0x0000
  FILE_TYPE_DISK    = 0x0001
  FILE_TYPE_CHAR    = 0x0002
  FILE_TYPE_PIPE    = 0x0003
  FILE_TYPE_REMOTE  = 0x8000

  FILE_ATTRIBUTE_READONLY      = 0x00000001
  FILE_ATTRIBUTE_HIDDEN        = 0x00000002
  FILE_ATTRIBUTE_SYSTEM        = 0x00000004
  FILE_ATTRIBUTE_DIRECTORY     = 0x00000010
  FILE_ATTRIBUTE_ARCHIVE       = 0x00000020
  FILE_ATTRIBUTE_ENCRYPTED     = 0x00000040
  FILE_ATTRIBUTE_NORMAL        = 0x00000080
  FILE_ATTRIBUTE_TEMPORARY     = 0x00000100
  FILE_ATTRIBUTE_SPARSE_FILE   = 0x00000200
  FILE_ATTRIBUTE_REPARSE_POINT = 0x00000400
  FILE_ATTRIBUTE_COMPRESSED    = 0x00000800
  FILE_ATTRIBUTE_OFFLINE       = 0x00001000

  FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = 0x00002000

  undef_method :atime, :ctime, :mtime, :blksize

  public

  attr_reader :atime
  attr_reader :ctime
  attr_reader :mtime
  attr_reader :blksize

  # The version of the win32-file-stat library
  VERSION = '1.4.0'

  def initialize(file)
    file = File.expand_path(file).tr('/', "\\")

    unless file.encoding.to_s == 'UTF-16LE'
      file = file.concat(0.chr).encode('UTF-16LE')
    end

    file = "\\\\?\\".encode('UTF-16LE') + file

    @blksize = get_blksize(file)

    data   = WIN32_FIND_DATA.new
    handle = FindFirstFile(file, data)
    errno  = FFI.errno

    if handle == INVALID_HANDLE_VALUE
      raise SystemCallError.new('FindFirstFile', errno)
    end

    if handle == ERROR_FILE_NOT_FOUND
      handle = FindNextFile(file, data)

      if handle == INVALID_HANDLE_VALUE
        raise SystemCallError.new('FindNextFile', errno)
      end
    end

    begin
      @file  = data[:cFileName].to_ptr.read_string(file.size).delete(0.chr)
      @attr  = data[:dwFileAttributes]
      @atime = Time.at(data.atime)
      @ctime = Time.at(data.ctime)
      @mtime = Time.at(data.mtime)

      @archive = @attr & FILE_ATTRIBUTE_ARCHIVE > 0
    ensure
      FindClose(handle)
    end
  end

  def archive?
    @archive
  end

  private

  def get_blksize(path)
    ptr = FFI::MemoryPointer.from_string(path)

    if PathStripToRoot(ptr)
      fpath = ptr.read_string_length(path.size * 2).split(0.chr * 2).first
      fpath = fpath.delete(0.chr).encode('UTF-16LE')
    else
      fpath = nil
    end

    size = nil

    sectors = FFI::MemoryPointer.new(:ulong)
    bytes   = FFI::MemoryPointer.new(:ulong)
    free    = FFI::MemoryPointer.new(:ulong)
    total   = FFI::MemoryPointer.new(:ulong)

    if GetDiskFreeSpace(fpath, sectors, bytes, free, total)
      size = sectors.read_ulong * bytes.read_ulong
    end

    size
  end
end

if $0 == __FILE__
  stat = File::Stat.new('stat.orig')
  p stat.blksize
end
