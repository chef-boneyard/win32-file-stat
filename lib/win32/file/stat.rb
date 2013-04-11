require File.join(File.dirname(__FILE__), 'windows', 'constants')
require File.join(File.dirname(__FILE__), 'windows', 'structs')
require File.join(File.dirname(__FILE__), 'windows', 'functions')

class File::Stat
  include Windows::Constants
  include Windows::Structs
  include Windows::Functions

  undef_method :atime, :ctime, :mtime, :blksize, :blockdev?, :blocks
  undef_method :size

  attr_reader :atime
  attr_reader :ctime
  attr_reader :mtime
  attr_reader :blksize
  attr_reader :blocks
  attr_reader :size

  # The version of the win32-file-stat library
  VERSION = '1.4.0'

  def initialize(file)
    path = File.expand_path(file).tr('/', "\\")

    # Must call these before chopping trailing backslash
    @blockdev = get_blockdev(path)
    @blksize  = get_blksize(path)

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

      @archive = @attr & FILE_ATTRIBUTE_ARCHIVE > 0
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
end

if $0 == __FILE__
  stat = File::Stat.new('stat.orig')
  p stat.size
  p stat.blocks
end
