require 'ffi'

class File::Stat
  extend FFI::Library
  ffi_lib :kernel32

  private

  attach_function :FindFirstFile, :FindFirstFileW, [:buffer_in, :pointer], :ulong
  attach_function :FindNextFile, :FindNextFileW, [:buffer_in, :pointer], :bool
  attach_function :FindClose, [:ulong], :bool

  MAX_PATH = 260

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
  end

  # p WIN32_FIND_DATA.size

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

  public

  # The version of the win32-file-stat library
  VERSION = '1.4.0'

  def initialize(file)
    file = File.expand_path(file).tr('/', "\\")

    unless file.encoding.to_s == 'UTF-16LE'
      file = file.concat(0.chr).encode('UTF-16LE')
    end

    file = "\\\\?\\".encode('UTF-16LE') + file

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
      @file = data[:cFileName].to_ptr.read_string(file.size).delete(0.chr)
      @attr = data[:dwFileAttributes]
    ensure
      FindClose(handle)
    end
  end

  def archive?
    @attr & FILE_ATTRIBUTE_ARCHIVE > 0
  end
end

#File::Stat.new('test.txt')
