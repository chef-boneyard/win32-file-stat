require File.join(File.dirname(__FILE__), 'windows', 'constants')
require File.join(File.dirname(__FILE__), 'windows', 'structs')
require File.join(File.dirname(__FILE__), 'windows', 'functions')
require 'pp'

class File::Stat
  include Windows::Constants
  include Windows::Structs
  include Windows::Functions
  include Comparable

  undef_method :atime, :ctime, :mtime, :blksize, :blockdev?, :blocks, :chardev?
  undef_method :dev, :directory?, :executable?, :executable_real?, :file?
  undef_method :ftype, :gid, :ino, :mode, :nlink, :pipe?, :readable?, :rdev
  undef_method :readable_real?, :size, :size?, :socket?, :symlink?, :uid
  undef_method :writable?, :writable_real?, :zero?
  undef_method :<=>, :inspect, :pretty_print

  attr_reader :atime
  attr_reader :ctime
  attr_reader :mtime
  attr_reader :blksize
  attr_reader :blocks
  attr_reader :gid
  attr_reader :ino
  attr_reader :mode
  attr_reader :nlink
  attr_reader :size
  attr_reader :uid

  # The version of the win32-file-stat library
  VERSION = '1.4.0'

  def initialize(file)
    path  = file.tr('/', "\\")
    @path = path

    begin
      # The handle returned will be used by other functions
      handle = get_handle(path)

      @blockdev = get_blockdev(path)
      @blksize  = get_blksize(path)
      @filetype = get_filetype(handle)

      # Get specific file types
      @chardev  = @filetype == FILE_TYPE_CHAR
      @regular  = @filetype == FILE_TYPE_DISK
      @pipe     = @filetype == FILE_TYPE_PIPE

      if @blockdev || @chardev || @pipe
        data = WIN32_FIND_DATA.new
        CloseHandle(handle)

        handle = FindFirstFileA(path, data)

        if handle == INVALID_HANDLE_VALUE
          raise SystemCallError.new('FindFirstFile', FFI.errno)
        end

        FindClose(handle)

        @nlink = 1 # Default from stat/wstat function.
      else
        data = BY_HANDLE_FILE_INFORMATION.new

        unless GetFileInformationByHandle(handle, data)
          raise SystemCallError.new('GetFileInformationByHandle', FFI.errno)
        end

        @nlink = data[:nNumberOfLinks]
      end

      # Not supported and/or meaningless on MS Windows
      @dev_major     = nil
      @dev_minor     = nil
      @gid           = 0    # TODO: Make this work?
      @grpowned      = true # TODO: Make this work
      @ino           = 0
      @owned         = true # TODO: Make this work
      @readable      = true # TODO: Make this work
      @readable_real = true # TODO: Same as readable
      @rdev_major    = nil
      @rdev_minor    = nil
      @setgid        = false
      @setuid        = false
      @sticky        = false
      @uid           = 0     # TODO: Make this work
      @writable      = true  # TODO: Make this work
      @writable_real = true  # TODO: Same as writeable

      # Originally used GetBinaryType, but it only worked
      # for .exe files, and it could return false positives.
      @executable = %w[.bat .cmd .com .exe].include?(File.extname(@path).downcase)

      # Set blocks equal to size / blksize, rounded up
      case @blksize
        when nil
          @blocks = nil
        when 0
          @blocks = 0
        else
          @blocks  = (data.size.to_f / @blksize.to_f).ceil
      end

      @attr  = data[:dwFileAttributes]
      @atime = Time.at(data.atime)
      @ctime = Time.at(data.ctime)
      @mtime = Time.at(data.mtime)
      @size  = data.size

      @archive       = @attr & FILE_ATTRIBUTE_ARCHIVE > 0
      @compressed    = @attr & FILE_ATTRIBUTE_COMPRESSED > 0
      @directory     = @attr & FILE_ATTRIBUTE_DIRECTORY > 0
      @encrypted     = @attr & FILE_ATTRIBUTE_ENCRYPTED > 0
      @hidden        = @attr & FILE_ATTRIBUTE_HIDDEN > 0
      @indexed       = @attr & ~FILE_ATTRIBUTE_NOT_CONTENT_INDEXED > 0
      @normal        = @attr & FILE_ATTRIBUTE_NORMAL > 0
      @offline       = @attr & FILE_ATTRIBUTE_OFFLINE > 0
      @readonly      = @attr & FILE_ATTRIBUTE_READONLY > 0
      @reparse_point = @attr & FILE_ATTRIBUTE_REPARSE_POINT > 0
      @sparse        = @attr & FILE_ATTRIBUTE_SPARSE_FILE > 0
      @system        = @attr & FILE_ATTRIBUTE_SYSTEM > 0
      @temporary     = @attr & FILE_ATTRIBUTE_TEMPORARY > 0

      @mode = get_mode

      if @reparse_point
        @symlink = get_symlink(path)
      else
        @symlink = false
      end
    ensure
      CloseHandle(handle) if handle
    end
  end

  ## Comparable

  # Compares two File::Stat objects using modification time.
  #--
  # Custom implementation necessary since we altered File::Stat.
  #
  def <=>(other)
    @mtime.to_i <=> other.mtime.to_i
  end

  ## Other

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

  def dev
    value = nil
    path  = File.expand_path(@path)

    unless PathIsUNCA(path)
      ptr = FFI::MemoryPointer.from_string(path)
      if PathStripToRootA(ptr)
        value = ptr.read_string
      end
    end

    value
  end

  def directory?
    @directory
  end

  def encrypted?
    @encrypted
  end

  def executable?
    @executable
  end

  alias executable_real? executable?

  def file?
    @regular
  end

  def hidden?
    @hidden
  end

  def indexed?
    @indexed
  end

  alias content_indexed? indexed?

  def normal?
    @normal
  end

  def offline?
    @offline
  end

  def rdev
    PathGetDriveNumberA(File.expand_path(@path))
  end

  def readable?
    @readable
  end

  # TODO: Make this an alias for readable?
  def readable_real?
    @readable_real
  end

  def readonly?
    @readonly
  end

  alias read_only? readonly?

  def pipe?
    @pipe
  end

  alias socket? pipe?

  def reparse_point?
    @reparse_point
  end

  def size?
    @size > 0 ? @size : nil
  end

  def sparse?
    @sparse
  end

  def symlink?
    @symlink
  end

  def system?
    @system
  end

  def temporary?
    @temporary
  end

  def writable?
    @writable
  end

  def writable_real?
    @writable_real
  end

  def zero?
    @size == 0
  end

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

  # Returns a stringified version of a File::Stat object.
  #
  def inspect
    members = %w[
      archive? atime blksize blockdev? blocks compressed? ctime dev
      encrypted? gid hidden? indexed? ino mode mtime rdev nlink normal?
      offline? readonly? reparse_point? size sparse? system? temporary?
      uid
    ]

    str = "#<#{self.class}"

    members.sort.each{ |mem|
      if mem == 'mode'
        str << " #{mem}=" << sprintf("0%o", send(mem.intern))
      elsif mem[-1].chr == '?' # boolean methods
        str << " #{mem.chop}=" << send(mem.intern).to_s
      else
        str << " #{mem}=" << send(mem.intern).to_s
      end
    }

    str
  end

  private

  # This is based on fileattr_to_unixmode in win32.c
  def get_mode
    mode = 0

    s_iread = 0x0100; s_iwrite = 0x0080; s_iexec = 0x0040
    s_ifreg = 0x8000; s_ifdir = 0x4000; s_iwusr = 0200
    s_iwgrp = 0020; s_iwoth = 0002;

    if @readonly
      mode |= s_iread
    else
      mode |= s_iread | s_iwrite | s_iwusr
    end

    if @directory
      mode |= s_ifdir | s_iexec
    else
      mode |= s_ifreg
    end

    if @executable
      mode |= s_iexec
    end

    mode |= (mode & 0700) >> 3;
    mode |= (mode & 0700) >> 6;

    mode &= ~(s_iwgrp | s_iwoth)

    mode
  end

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

  def get_handle(path)
    handle = CreateFileA(
      path,
      GENERIC_READ,
      FILE_SHARE_READ,
      nil,
      OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT,
      0
    )

    if handle == INVALID_HANDLE_VALUE
      raise SystemCallError.new('CreateFile', FFI.errno)
    end

    handle
  end

  def get_symlink(file)
    bool = false
    file = File.expand_path(file)

    begin
      data = WIN32_FIND_DATA.new
      handle = FindFirstFileA(file, data)

      if handle == INVALID_HANDLE_VALUE
        raise SystemCallError.new('FindFirstFile', FFI.errno)
      end

      if data[:dwReserved0] == IO_REPARSE_TAG_SYMLINK
        bool = true
      end
    ensure
      CloseHandle(handle)
    end

    bool
  end

  def get_filetype(handle)
    file_type = GetFileType(handle)

    if file_type == FILE_TYPE_UNKNOWN && FFI.errno != NO_ERROR
      raise SystemCallError.new('GetFileType', FFI.errno)
    end

    file_type
  end
end

if $0 == __FILE__
  #File::Stat.new(Dir.pwd)
  #File::Stat.new('stat.orig')
  #File::Stat.new('//scipio/users')
  #File::Stat.new('//scipio/users/djberge/Documents/command.txt')
  #File::Stat.new('NUL')
  #puts File::Stat.new(Dir.pwd).inspect
  #p File::Stat.new(Dir.pwd).dev
  #p File::Stat.new(Dir.pwd).rdev
  #p File::Stat.new('//scipio/users/djberge/Documents/command.txt').dev
  #p File::Stat.new('//scipio/users/djberge/Documents/command.txt').rdev
  p File::Stat.new('temp.txt').symlink?
  p File::Stat.new('temp2.txt').symlink?
  p File::Stat.new('temp.txt').nlink
end
