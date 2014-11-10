require_relative 'windows/helper'
require_relative 'windows/constants'
require_relative 'windows/structs'
require_relative 'windows/functions'
require 'pp'

class File::Stat
  include Windows::Stat::Constants
  include Windows::Stat::Structs
  include Windows::Stat::Functions
  include Comparable

  # We have to undefine these first in order to avoid redefinition warnings.
  undef_method :atime, :ctime, :mtime, :blksize, :blockdev?, :blocks, :chardev?
  undef_method :dev, :dev_major, :dev_minor, :directory?, :executable?
  undef_method :executable_real?, :file?
  undef_method :ftype, :gid, :grpowned?, :ino, :mode, :nlink, :owned?
  undef_method :pipe?, :readable?, :readable_real?, :rdev, :rdev_major
  undef_method :rdev_minor, :setuid?, :setgid?
  undef_method :size, :size?, :socket?, :sticky?, :symlink?, :uid
  undef_method :world_readable?, :world_writable?, :writable?, :writable_real?
  undef_method :<=>, :inspect, :pretty_print, :zero?

  # A Time object containing the last access time.
  attr_reader :atime

  # A Time object indicating when the file was last changed.
  attr_reader :ctime

  # A Time object containing the last modification time.
  attr_reader :mtime

  # The native filesystems' block size.
  attr_reader :blksize

  # The number of native filesystem blocks allocated for this file.
  attr_reader :blocks

  # The serial number of the file's volume.
  attr_reader :rdev

  # The file's unique identifier. Only valid for regular files.
  attr_reader :ino

  # Integer representing the permission bits of the file.
  attr_reader :mode

  # The number of hard links to the file.
  attr_reader :nlink

  # The size of the file in bytes.
  attr_reader :size

  # Nil on Windows
  attr_reader :dev_major, :dev_minor, :rdev_major, :rdev_minor

  # Alternate streams
  attr_reader :streams

  # The version of the win32-file-stat library
  WIN32_FILE_STAT_VERSION = '1.5.0'

  # Creates and returns a File::Stat object, which encapsulate common status
  # information for File objects on MS Windows sytems. The information is
  # recorded at the moment the File::Stat object is created; changes made to
  # the file after that point will not be reflected.
  #
  def initialize(file)
    file = string_check(file)

    path  = file.tr('/', "\\")
    @path = path

    @user_sid = get_file_sid(file, OWNER_SECURITY_INFORMATION)
    @grp_sid  = get_file_sid(file, GROUP_SECURITY_INFORMATION)

    @uid = @user_sid.split('-').last.to_i
    @gid = @grp_sid.split('-').last.to_i

    @owned = @user_sid == get_current_process_sid(TokenUser)
    @grpowned = @grp_sid == get_current_process_sid(TokenGroups)

    begin
      # The handle returned will be used by other functions
      handle = get_handle(path)

      @blockdev = get_blockdev(path)
      @blksize  = get_blksize(path)

      if handle
        @filetype = get_filetype(handle)
        @streams  = get_streams(handle)
        @chardev  = @filetype == FILE_TYPE_CHAR
        @regular  = @filetype == FILE_TYPE_DISK
        @pipe     = @filetype == FILE_TYPE_PIPE
      else
        @chardev = false
        @regular = false
        @pipe    = false
      end

      fpath = path.wincode

      if handle == nil || ((@blockdev || @chardev || @pipe) && GetDriveType(fpath) != DRIVE_REMOVABLE)
        data = WIN32_FIND_DATA.new
        CloseHandle(handle) if handle

        handle = FindFirstFile(fpath, data)

        if handle == INVALID_HANDLE_VALUE
          raise SystemCallError.new('FindFirstFile', FFI.errno)
        end

        FindClose(handle)
        handle = nil

        @nlink = 1 # Default from stat/wstat function.
        @ino   = nil
        @rdev  = nil
      else
        data = BY_HANDLE_FILE_INFORMATION.new

        unless GetFileInformationByHandle(handle, data)
          raise SystemCallError.new('GetFileInformationByHandle', FFI.errno)
        end

        @nlink = data[:nNumberOfLinks]
        @ino   = (data[:nFileIndexHigh] << 32) | data[:nFileIndexLow]
        @rdev  = data[:dwVolumeSerialNumber]
      end

      # Not supported and/or meaningless on MS Windows
      @dev_major      = nil
      @dev_minor      = nil
      @rdev_major     = nil
      @rdev_minor     = nil
      @setgid         = false
      @setuid         = false
      @sticky         = false

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

      @readable = access_check(path, GENERIC_READ)
      @readable_real = @readable

      # The MSDN docs say that the readonly attribute is honored for directories
      if @directory
        @writable = access_check(path, GENERIC_WRITE)
      else
        @writable = access_check(path, GENERIC_WRITE) && !@readonly
      end

      @writable_real = @writable

      @world_readable = access_check_world(path, FILE_READ_DATA)
      @world_writable = access_check_world(path, FILE_WRITE_DATA) && !@readonly

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

  # Returns whether or not the file is an archive file.
  #
  def archive?
    @archive
  end

  # Returns whether or not the file is a block device. For MS Windows a
  # block device is a removable drive, cdrom or ramdisk.
  #
  def blockdev?
    @blockdev
  end

  # Returns whether or not the file is a character device.
  #
  def chardev?
    @chardev
  end

  # Returns whether or not the file is compressed.
  #
  def compressed?
    @compressed
  end

  # Returns whether or not the file is a directory.
  #
  def directory?
    @directory
  end

  # Returns whether or not the file in encrypted.
  #
  def encrypted?
    @encrypted
  end

  # Returns whether or not the file is executable. Generally speaking, this
  # means .bat, .cmd, .com, and .exe files.
  #
  def executable?
    @executable
  end

  alias executable_real? executable?

  # Returns whether or not the file is a regular file, as opposed to a pipe,
  # socket, etc.
  #
  def file?
    @regular
  end

  # Returns the user ID of the file. If full_sid is true, then the full
  # string sid is returned instead.
  #--
  # The user id is the RID of the SID.
  #
  def gid(full_sid = false)
    full_sid ? @grp_sid : @gid
  end

  # Returns true if the process owner's ID is the same as one of the file's groups.
  #--
  # Internally we're checking the process sid against the TokenGroups sid.
  #
  def grpowned?
    @grpowned
  end

  # Returns whether or not the file is hidden.
  #
  def hidden?
    @hidden
  end

  # Returns whether or not the file is content indexed.
  #
  def indexed?
    @indexed
  end

  alias content_indexed? indexed?

  # Returns whether or not the file is 'normal'. This is only true if
  # virtually all other attributes are false.
  #
  def normal?
    @normal
  end

  # Returns whether or not the file is offline.
  #
  def offline?
    @offline
  end

  # Returns whether or not the current process owner is the owner of the file.
  #--
  # Internally we're checking the process sid against the owner's sid.
  def owned?
    @owned
  end

  # Returns the drive number of the disk containing the file, or -1 if there
  # is no associated drive number.
  #
  # If the +letter+ option is true, returns the drive letter instead. If there
  # is no drive letter, it will return nil.
  #--
  # This differs slightly from MRI in that it will return -1 if the path
  # does not have a drive letter.
  #
  # Note: Bug in JRuby as of JRuby 1.7.8, which does not expand NUL properly.
  #
  def dev(letter = false)
    fpath = File.expand_path(@path).wincode
    num = PathGetDriveNumber(fpath)

    if letter
      if num == -1
        nil
      else
        (num + 'A'.ord).chr + ':'
      end
    else
      num
    end
  end

  # Returns whether or not the file is readable by the process owner.
  #--
  # In Windows terms, we're checking for GENERIC_READ privileges.
  #
  def readable?
    @readable
  end

  # A synonym for File::Stat#readable?
  #
  def readable_real?
    @readable_real
  end

  # Returns whether or not the file is readonly.
  #
  def readonly?
    @readonly
  end

  alias read_only? readonly?

  # Returns whether or not the file is a pipe.
  #
  def pipe?
    @pipe
  end

  alias socket? pipe?

  # Returns whether or not the file is a reparse point.
  #
  def reparse_point?
    @reparse_point
  end

  # Returns false on MS Windows.
  #--
  # I had to explicitly define this because of a bug in JRuby.
  #
  def setgid?
    @setgid
  end

  # Returns false on MS Windows.
  #--
  # I had to explicitly define this because of a bug in JRuby.
  #
  def setuid?
    @setuid
  end

  # Returns whether or not the file size is zero.
  #
  def size?
    @size > 0 ? @size : nil
  end

  # Returns whether or not the file is a sparse file. In most cases a sparse
  # file is an image file.
  #
  def sparse?
    @sparse
  end

  # Returns false on MS Windows.
  #--
  # I had to explicitly define this because of a bug in JRuby.
  #
  def sticky?
    @sticky
  end

  # Returns whether or not the file is a symlink.
  #
  def symlink?
    @symlink
  end

  # Returns whether or not the file is a system file.
  #
  def system?
    @system
  end

  # Returns whether or not the file is being used for temporary storage.
  #
  def temporary?
    @temporary
  end

  # Returns the user ID of the file. If the +full_sid+ is true, then the
  # full string sid is returned instead.
  #--
  # The user id is the RID of the SID.
  #
  def uid(full_sid = false)
    full_sid ? @user_sid : @uid
  end

  # Returns whether or not the file is readable by others. Note that this
  # merely returns true or false, not permission bits (or nil).
  #--
  # In Windows terms, this is checking the access right FILE_READ_DATA against
  # the well-known SID "S-1-1-0", aka "Everyone".
  #
  #
  def world_readable?
    @world_readable
  end

  # Returns whether or not the file is writable by others. Note that this
  # merely returns true or false, not permission bits (or nil).
  #--
  # In Windows terms, this is checking the access right FILE_WRITE_DATA against
  # the well-known SID "S-1-1-0", aka "Everyone".
  #
  def world_writable?
    @world_writable
  end

  # Returns whether or not the file is writable by the current process owner.
  #--
  # In Windows terms, we're checking for GENERIC_WRITE privileges.
  #
  def writable?
    @writable
  end

  # A synonym for File::Stat#readable?
  #
  def writable_real?
    @writable_real
  end

  # Returns whether or not the file size is zero.
  #
  def zero?
    @size == 0
  end

  # Identifies the type of file. The return string is one of 'file',
  # 'directory', 'characterSpecial', 'socket' or 'unknown'.
  #
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
      offline? readonly? reparse_point? size sparse? system? streams
      temporary? uid
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

  # A custom pretty print method.  This was necessary not only to handle
  # the additional attributes, but to work around an error caused by the
  # builtin method for the current File::Stat class (see pp.rb).
  #
  def pretty_print(q)
    members = %w[
      archive? atime blksize blockdev? blocks compressed? ctime dev
      encrypted? gid hidden? indexed? ino mode mtime rdev nlink normal?
      offline? readonly? reparse_point? size sparse? streams system? temporary?
      uid
    ]

    q.object_group(self){
      q.breakable
      members.each{ |mem|
        q.group{
          q.text("#{mem}".ljust(15) + "=> ")
          if mem == 'mode'
            q.text(sprintf("0%o", send(mem.intern)))
          else
            val = self.send(mem.intern)
            if val.nil?
              q.text('nil')
            else
              q.text(val.to_s)
            end
          end
        }
        q.comma_breakable unless mem == members.last
      }
    }
  end

  private

  # Allow stringy arguments
  def string_check(arg)
    return arg if arg.is_a?(String)
    return arg.send(:to_str) if arg.respond_to?(:to_str, true) # MRI honors private to_str
    return arg.to_path if arg.respond_to?(:to_path)
    raise TypeError
  end

  # This is based on fileattr_to_unixmode in win32.c
  #
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

  # Returns whether or not +path+ is a block device.
  #
  def get_blockdev(path)
    ptr = FFI::MemoryPointer.from_string(path.wincode)

    if PathStripToRoot(ptr)
      fpath = ptr.read_bytes(path.size * 2).split("\000\000").first
    else
      fpath = nil
    end

    case GetDriveType(fpath)
      when DRIVE_REMOVABLE, DRIVE_CDROM, DRIVE_RAMDISK
        true
      else
        false
    end
  end

  # Returns the blksize for +path+.
  #---
  # The jruby-ffi gem (as of 1.9.3) reports a failure here where it shouldn't.
  # Consequently, this method returns 4096 automatically for now on JRuby.
  #
  def get_blksize(path)
    return 4096 if RUBY_PLATFORM == 'java' # Bug in jruby-ffi

    ptr = FFI::MemoryPointer.from_string(path.wincode)

    if PathStripToRoot(ptr)
      fpath = ptr.read_bytes(path.size * 2).split("\000\000").first
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
    else
      unless PathIsUNC(fpath)
        raise SystemCallError.new('GetDiskFreeSpace', FFI.errno)
      end
    end

    size
  end

  # Generic method for retrieving a handle.
  #
  def get_handle(path)
    fpath = path.wincode

    handle = CreateFile(
      fpath,
      GENERIC_READ,
      FILE_SHARE_READ,
      nil,
      OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT,
      0
    )

    if handle == INVALID_HANDLE_VALUE
      return nil if FFI.errno == 32 # ERROR_SHARING_VIOLATION. Locked files.
      raise SystemCallError.new('CreateFile', FFI.errno)
    end

    handle
  end

  # Determines whether or not +file+ is a symlink.
  #
  def get_symlink(file)
    bool = false
    fpath = File.expand_path(file).wincode

    begin
      data = WIN32_FIND_DATA.new
      handle = FindFirstFile(fpath, data)

      if handle == INVALID_HANDLE_VALUE
        raise SystemCallError.new('FindFirstFile', FFI.errno)
      end

      if data[:dwReserved0] == IO_REPARSE_TAG_SYMLINK
        bool = true
      end
    ensure
      FindClose(handle) if handle
    end

    bool
  end

  # Returns the filetype for the given +handle+.
  #
  def get_filetype(handle)
    file_type = GetFileType(handle)

    if file_type == FILE_TYPE_UNKNOWN && FFI.errno != NO_ERROR
      raise SystemCallError.new('GetFileType', FFI.errno)
    end

    file_type
  end

  def get_streams(handle)
    io_status = IO_STATUS_BLOCK.new
    ptr = FFI::MemoryPointer.new(:uchar, 1024 * 64)

    rv = NtQueryInformationFile(handle, io_status, ptr, ptr.size, FileStreamInformation)

    if rv != 0
      raise SystemCallError.new('NtQueryInformationFile', rv)
    end

    arr = []

    while true
      info = FILE_STREAM_INFORMATION.new(ptr)
      break if info[:StreamNameLength] == 0
      arr << info[:StreamName].to_ptr.read_bytes(info[:StreamNameLength]).delete(0.chr)
      break if info[:NextEntryOffset] == 0
      info = FILE_STREAM_INFORMATION.new(ptr += info[:NextEntryOffset])
    end

    arr
  end

  # Return a sid of the file's owner.
  #
  def get_file_sid(file, info)
    wfile = file.wincode
    size_needed_ptr = FFI::MemoryPointer.new(:ulong)

    # First pass, get the size needed
    bool = GetFileSecurity(wfile, info, nil, 0, size_needed_ptr)

    size_needed  = size_needed_ptr.read_ulong
    security_ptr = FFI::MemoryPointer.new(size_needed)

    # Second pass, this time with the appropriately sized security pointer
    bool = GetFileSecurity(wfile, info, security_ptr, security_ptr.size, size_needed_ptr)

    unless bool
      error = FFI.errno
      return "S-1-5-80-0" if error == 32 # ERROR_SHARING_VIOLATION. Locked files, etc.
      raise SystemCallError.new("GetFileSecurity", error)
    end

    sid_ptr   = FFI::MemoryPointer.new(:pointer)
    defaulted = FFI::MemoryPointer.new(:bool)

    if info == OWNER_SECURITY_INFORMATION
      bool = GetSecurityDescriptorOwner(security_ptr, sid_ptr, defaulted)
      meth = "GetSecurityDescriptorOwner"
    else
      bool = GetSecurityDescriptorGroup(security_ptr, sid_ptr, defaulted)
      meth = "GetSecurityDescriptorGroup"
    end

    raise SystemCallError.new(meth, FFI.errno) unless bool

    ptr = FFI::MemoryPointer.new(:string)

    unless ConvertSidToStringSid(sid_ptr.read_pointer, ptr)
      raise SystemCallError.new("ConvertSidToStringSid")
    end

    ptr.read_pointer.read_string
  end

  # Return the sid of the current process.
  #
  def get_current_process_sid(token_type)
    token = FFI::MemoryPointer.new(:uintptr_t)
    sid = nil

    begin
      # Get the current process sid
      unless OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, token)
        raise SystemCallError.new("OpenProcessToken", FFI.errno)
      end

      token   = token.read_pointer.to_i
      rlength = FFI::MemoryPointer.new(:pointer)

      if token_type == TokenUser
        buf = 0.chr * 512
      else
        buf = TOKEN_GROUP.new
      end

      unless GetTokenInformation(token, token_type, buf, buf.size, rlength)
        raise SystemCallError.new("GetTokenInformation", FFI.errno)
      end

      if token_type == TokenUser
        tsid = buf[FFI.type_size(:pointer)*2, (rlength.read_ulong - FFI.type_size(:pointer)*2)]
      else
        tsid = buf[:Groups][0][:Sid]
      end

      ptr = FFI::MemoryPointer.new(:string)

      unless ConvertSidToStringSid(tsid, ptr)
        raise SystemCallError.new("ConvertSidToStringSid")
      end

      sid = ptr.read_pointer.read_string
    ensure
      CloseHandle(token) if token
    end

    sid
  end

  # Returns whether or not the current process has given access rights for +path+.
  #
  def access_check(path, access_rights)
    wfile = path.wincode
    check = false
    size_needed_ptr = FFI::MemoryPointer.new(:ulong)

    flags = OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION |
      DACL_SECURITY_INFORMATION

    # First attempt, get the size needed
    bool = GetFileSecurity(wfile, flags, nil, 0, size_needed_ptr)

    # If it fails horribly here, assume the answer is no.
    if !bool && FFI.errno != ERROR_INSUFFICIENT_BUFFER
      return false
    end

    size_needed  = size_needed_ptr.read_ulong
    security_ptr = FFI::MemoryPointer.new(size_needed)

    # Second attempt, now with the needed size
    if GetFileSecurity(wfile, flags, security_ptr, size_needed, size_needed_ptr)
      token = FFI::MemoryPointer.new(:uintptr_t)

      pflags = TOKEN_IMPERSONATE | TOKEN_QUERY | TOKEN_DUPLICATE | STANDARD_RIGHTS_READ

      if OpenProcessToken(GetCurrentProcess(), pflags, token)
        begin
          token  = token.read_pointer.to_i
          token2 = FFI::MemoryPointer.new(:uintptr_t)

          if DuplicateToken(token, SecurityImpersonation, token2)
            begin
              token2 = token2.read_pointer.to_i
              mapping = GENERIC_MAPPING.new
              privileges = PRIVILEGE_SET.new
              privileges[:PrivilegeCount] = 0
              privileges_length = privileges.size

              mapping[:GenericRead] = FILE_GENERIC_READ
              mapping[:GenericWrite] = FILE_GENERIC_WRITE
              mapping[:GenericExecute] = FILE_GENERIC_EXECUTE
              mapping[:GenericAll] = FILE_ALL_ACCESS

              rights_ptr = FFI::MemoryPointer.new(:ulong)
              rights_ptr.write_ulong(access_rights)

              MapGenericMask(rights_ptr, mapping)
              rights = rights_ptr.read_ulong

              result_ptr = FFI::MemoryPointer.new(:ulong)
              privileges_length_ptr = FFI::MemoryPointer.new(:ulong)
              privileges_length_ptr.write_ulong(privileges_length)
              granted_access_ptr = FFI::MemoryPointer.new(:ulong)

              bool = AccessCheck(
                security_ptr,
                token2,
                rights,
                mapping,
                privileges,
                privileges_length_ptr,
                granted_access_ptr,
                result_ptr
              )

              if bool
                check = result_ptr.read_ulong == 1
              else
                raise SystemCallError.new('AccessCheck', FFI.errno)
              end
            ensure
              CloseHandle(token2)
            end
          end
        ensure
          CloseHandle(token)
        end
      end
    end

    check
  end

  # Returns whether or not the Everyone has given access rights for +path+.
  #
  def access_check_world(path, access_rights)
    wfile = path.wincode
    check = false
    size_needed_ptr = FFI::MemoryPointer.new(:ulong)

    flags = DACL_SECURITY_INFORMATION

    # First attempt, get the size needed
    bool = GetFileSecurity(wfile, flags, nil, 0, size_needed_ptr)

    # If it fails horribly here, assume the answer is no.
    if !bool && FFI.errno != ERROR_INSUFFICIENT_BUFFER
      return false
    end

    size_needed  = size_needed_ptr.read_ulong
    security_ptr = FFI::MemoryPointer.new(size_needed)

    # Second attempt, now with the needed size
    if GetFileSecurity(wfile, flags, security_ptr, size_needed, size_needed_ptr)
        present_ptr   = FFI::MemoryPointer.new(:ulong)
        pdacl_ptr     = FFI::MemoryPointer.new(:pointer)
        defaulted_ptr = FFI::MemoryPointer.new(:ulong)

        bool = GetSecurityDescriptorDacl(
          security_ptr,
          present_ptr,
          pdacl_ptr,
          defaulted_ptr
        )

        # If it fails, or the dacl isn't present, return false.
        if !bool || present_ptr.read_ulong == 0
          return false
        end

        pdacl = pdacl_ptr.read_pointer
        psid_ptr = FFI::MemoryPointer.new(:pointer)

        # S-1-1-0 is the well known SID for "Everyone".
        ConvertStringSidToSid('S-1-1-0', psid_ptr)

        psid = psid_ptr.read_pointer
        trustee_ptr = FFI::MemoryPointer.new(TRUSTEE)

        BuildTrusteeWithSid(trustee_ptr, psid)

        rights_ptr = FFI::MemoryPointer.new(:ulong)

        if GetEffectiveRightsFromAcl(pdacl, trustee_ptr, rights_ptr) == NO_ERROR
          rights = rights_ptr.read_ulong
          check = (rights & access_rights) == access_rights
        end
    end

    check
  end
end
