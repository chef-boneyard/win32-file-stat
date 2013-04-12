require File.join(File.dirname(__FILE__), 'windows', 'constants')
require File.join(File.dirname(__FILE__), 'windows', 'structs')
require File.join(File.dirname(__FILE__), 'windows', 'functions')

class File::Stat
  include Windows::Constants
  include Windows::Structs
  include Windows::Functions

  undef_method :atime, :ctime, :mtime, :blksize, :blockdev?, :blocks, :chardev?
  undef_method :directory?, :executable?, :executable_real?, :file?, :ftype
  undef_method :pipe?, :size

  attr_reader :atime
  attr_reader :ctime
  attr_reader :mtime
  attr_reader :blksize
  attr_reader :blocks
  attr_reader :size

  # The version of the win32-file-stat library
  VERSION = '1.4.0'

  def initialize(file)
    path = file.tr('/', "\\")

    # Must call these before chopping trailing backslash
    @blockdev = get_blockdev(path)
    @blksize  = get_blksize(path)
    @filetype = get_filetype(path)

    # Get specific file types
    @chardev  = @filetype == FILE_TYPE_CHAR
    @regular  = @filetype == FILE_TYPE_DISK
    @pipe     = @filetype == FILE_TYPE_PIPE

    ptr = FFI::MemoryPointer.new(:ulong)
    @executable = GetBinaryTypeA(path, ptr)

    # Must remove trailing backslashes for FindFirstFile
    path.chop! if PathRemoveBackslashA(path) == "\\"

    data   = WIN32_FIND_DATA.new
    handle = FindFirstFileA(path, data)
    errno  = FFI.errno

    if handle == INVALID_HANDLE_VALUE
      raise SystemCallError.new('FindFirstFile', errno)
    end

    if handle == ERROR_FILE_NOT_FOUND
      bool = FindNextFileA(handle, data)

      if !bool && FFI.errno != ERROR_NO_MORE_FILES
        raise SystemCallError.new('FindNextFile', FFI.errno)
      end
    end

    # Set blocks equal to size / blksize, rounded up
    case @blksize
      when nil
        @blocks = nil
      when 0
        @blocks = 0
      else
        @blocks  = (data.size.to_f / @blksize.to_f).ceil
    end

    begin
      @file  = data[:cFileName].to_ptr.read_string(file.size).delete(0.chr)
      @attr  = data[:dwFileAttributes]
      @atime = Time.at(data.atime)
      @ctime = Time.at(data.ctime)
      @mtime = Time.at(data.mtime)
      @size  = data.size

      @archive    = @attr & FILE_ATTRIBUTE_ARCHIVE > 0
      @compressed = @attr & FILE_ATTRIBUTE_COMPRESSED > 0
      @directory  = @attr & FILE_ATTRIBUTE_DIRECTORY > 0
    ensure
      FindClose(handle)
    end
  end

  def archive?
    @archive
  end

  def blockdev?
    @blockdev
  end

  def chardev?
    @chardev
  end

  def compressed?
    @compressed
  end

  def directory?
    @directory
  end

  def executable?
    @executable
  end

  def file?
    @regular
  end

  def pipe?
    @pipe
  end

  alias executable_real? executable?

  def ftype
    return 'directory' if @directory

    case @filetype
      when FILE_TYPE_CHAR
        'characterSpecial'
      when FILE_TYPE_DISK
        'file'
      when FILE_TYPE_PIPE
        'socket'
      else
        if blockdev?
          'blockSpecial'
        else
          'unknown'
        end
    end
  end

  private

  def get_blockdev(path)
    ptr = FFI::MemoryPointer.from_string(path)

    if PathStripToRootA(ptr)
      fpath = ptr.read_string
    else
      fpath = nil
    end

    case GetDriveTypeA(fpath)
      when DRIVE_REMOVABLE, DRIVE_CDROM, DRIVE_RAMDISK
        true
      else
        false
    end
  end

  def get_blksize(path)
    ptr = FFI::MemoryPointer.from_string(path)

    if PathStripToRootA(ptr)
      fpath = ptr.read_string
    else
      fpath = nil
    end

    size = nil

    sectors = FFI::MemoryPointer.new(:ulong)
    bytes   = FFI::MemoryPointer.new(:ulong)
    free    = FFI::MemoryPointer.new(:ulong)
    total   = FFI::MemoryPointer.new(:ulong)

    if GetDiskFreeSpaceA(fpath, sectors, bytes, free, total)
      size = sectors.read_ulong * bytes.read_ulong
    end

    size
  end

  def get_filetype(file)
    begin
      handle = CreateFileA(
        file,
        0,
        0,
        nil,
        OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS, # Need this for directories
        0
      )

      # TODO: Deal with locked files

      if handle == INVALID_HANDLE_VALUE
        raise SystemCallError.new('CreateFile', FFI.errno)
      end

      file_type = GetFileType(handle)

      if file_type == FILE_TYPE_UNKNOWN && FFI.errno != NO_ERROR
        raise SystemCallError.new('GetFileType', FFI.errno)
      end
    ensure
      CloseHandle(handle) if handle
    end

    file_type
  end
end

if $0 == __FILE__
  stat = File::Stat.new('NUL')
  p stat.ftype
end
