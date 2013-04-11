require File.join(File.dirname(__FILE__), 'windows', 'constants')
require File.join(File.dirname(__FILE__), 'windows', 'structs')
require File.join(File.dirname(__FILE__), 'windows', 'functions')

class File::Stat
  include Windows::Constants
  include Windows::Structs
  include Windows::Functions

  undef_method :atime, :ctime, :mtime, :blksize

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

    # This seems to cause confusion
    #file = "\\\\?\\".encode('UTF-16LE') + file

    # Deal with trailing slashes and root paths
    while (PathRemoveBackslash(file) == ""); end
    file = file[0..-3] if PathIsRoot(file)

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
  #stat = File::Stat.new('stat.orig')
  stat = File::Stat.new("C:\\")
  p stat.blksize
end
