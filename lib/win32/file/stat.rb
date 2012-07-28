require 'ffi'

class File::Stat
  extend FFI::Library
  ffi_lib :kernel32

  private

  attach_function :CloseHandle, [:ulong], :bool
  attach_function :CreateFile, :CreateFileA, [:string, :ulong, :ulong, :pointer, :ulong, :ulong, :ulong], :ulong
  attach_function :FindFirstFile, :FindFirstFileA, [:string, :pointer], :ulong
  attach_function :FindNextFile, :FindNextFileA, [:string, :pointer], :bool
  attach_function :FindClose, [:ulong], :bool
  attach_function :GetDiskFreeSpace, :GetDiskFreeSpaceA, [:string, :pointer, :pointer, :pointer, :pointer], :bool
  attach_function :GetDriveType, :GetDriveTypeA, [:string], :uint
  attach_function :GetFileType, [:ulong], :ulong
  attach_function :QueryDosDevice, :QueryDosDeviceA, [:string, :string, :ulong], :ulong
  attach_function :SetErrorMode, [:uint], :uint

  ffi_lib :shlwapi

  attach_function :PathStripToRoot, :PathStripToRootA, [:pointer], :bool

  MAX_PATH = 260
  DRIVE_REMOVABLE = 2
  DRIVE_CDROM = 5
  DRIVE_RAMDISK = 6
  OPEN_EXISTING = 3
  FILE_FLAG_BACKUP_SEMANTICS = 0x02000000

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

  undef_method :atime, :ctime, :mtime, :blksize, :blockdev?, :blocks, :directory?

  public

  attr_reader :atime
  attr_reader :ctime
  attr_reader :mtime
  attr_reader :blksize
  attr_reader :blocks

  # The version of the win32-file-stat library
  VERSION = '1.4.0'

  def initialize(file)
    begin
      original_error_mode = SetErrorMode(1) # Disable popups
      file = File.expand_path(file).tr('/', "\\")

      @blksize  = get_blksize(file)
      @blockdev = get_blockdev(file)
      @size     = File.size(file)

      # Best guess
      case @blksize
        when nil
          @blocks = nil
        when 0
          @blocks = 0
        else
          @blocks = (@size.to_f / @blksize.to_f).ceil
      end

      # FindFirstFile doesn't like trailing backslashes
      file.chop! while file[-1].chr == "\\"

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

        @archive    = @attr & FILE_ATTRIBUTE_ARCHIVE > 0
        @compressed = @attr & FILE_ATTRIBUTE_COMPRESSED > 0
        @directory  = @attr & FILE_ATTRIBUTE_DIRECTORY > 0
      ensure
        FindClose(handle)
      end
    ensure
      SetErrorMode(original_error_mode)
    end
  end

  def archive?
    @archive
  end

  def blockdev?
    @blockdev
  end

  def compressed?
    @compressed
  end

  def directory?
    @directory
  end

  private

  def get_blksize(path)
    ptr = FFI::MemoryPointer.from_string(path)

    if PathStripToRoot(ptr)
      fpath = ptr.read_string
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

  def get_blockdev(path)
    bool = false
    blockdevs = [DRIVE_REMOVABLE, DRIVE_CDROM, DRIVE_RAMDISK]

    if blockdevs.include?(GetDriveType(path))
      bool = true
    end

    bool
  end

=begin
  def get_file_type(file)
    begin
      handle = CreateFile(
        file,
        0,
        0,
        nil,
        OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS, # Need this for directories
        nil
      )

      error_num = GetLastError()

      # CreateFile() chokes on locked files
      if error_num == ERROR_SHARING_VIOLATION
        drive  = file[0,4] + 0.chr * 2
        device = 0.chr * 512
        QueryDosDeviceW(drive, device, 256)
        file = device.strip + 0.chr + file[4..-1]
        handle = get_handle(file)
      end

      # We raise a SystemCallError explicitly here in order to maintain
      # compatibility with the FileUtils module.
      if handle == INVALID_HANDLE_VALUE
        raise SystemCallError, get_last_error(error_num)
      end

      file_type = GetFileType(handle)
      error_num = GetLastError()
    ensure
      CloseHandle(handle)
    end

    if file_type == FILE_TYPE_UNKNOWN && error_num != NO_ERROR
      raise SystemCallError, get_last_error(error_num)
    end

    file_type
  end
=end
end

if $0 == __FILE__
  file = 'stat.orig'
  file = "C:"
  stat = File::Stat.new(file)
  p file
  p stat.blksize
  p stat.atime
  p stat.ctime
  p stat.mtime
end
