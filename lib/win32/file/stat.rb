require 'windows/msvcrt/buffer'
require 'windows/msvcrt/file'
require 'windows/filesystem'
require 'windows/device_io'
require 'windows/path'
require 'windows/file'
require 'windows/error'
require 'windows/handle'
require 'windows/volume'
require 'windows/process'
require 'windows/security'
require 'windows/time'
require 'windows/ntfs/winternl'
require 'pp'

class File::Stat
   include Windows::MSVCRT::Buffer
   include Windows::MSVCRT::File
   include Windows::DeviceIO
   include Windows::FileSystem
   include Windows::Path
   include Windows::File
   include Windows::Error
   include Windows::Handle
   include Windows::Volume
   include Windows::Process
   include Windows::Security
   include Windows::Time
   include Windows::NTFS::Winternl
   include Comparable
   
   # The version of the win32-file-stat library
   VERSION = '1.3.4'

   private
   
   # :stopdoc: 

   # Defined in Ruby's win32.h.  Not meant for public consumption.
   S_IWGRP = 0020
   S_IWOTH = 0002
   
   # This is the only way to avoid a -w warning for initialize. We remove
   # it later, after we've defined our initialize method.
   alias old_init initialize
   
   # Make this library -w clean
   undef_method(:atime, :blksize, :blockdev?, :blocks, :chardev?, :ctime)
   undef_method(:dev, :directory?, :executable?, :file?, :ftype, :gid, :ino)
   undef_method(:executable_real?, :grpowned?, :mode, :mtime, :nlink, :owned?)
   undef_method(:pipe?, :readable?, :rdev, :readable_real?, :setgid?, :setuid?)
   undef_method(:size, :size?, :socket?, :sticky?, :symlink?, :uid, :writable?)
   undef_method(:writable_real?, :zero?)
   undef_method(:pretty_print, :inspect, :<=>)
   
   public

   # Always nil. Provided for interface compatibility only.
   attr_reader :dev_major
   attr_reader :dev_minor
   attr_reader :rdev_major
   attr_reader :rdev_minor
   
   # :startdoc:
   
   # Creates and returns a File::Stat object, which encapsulate common status
   # information for File objects on MS Windows sytems. The information is
   # recorded at the moment the File::Stat object is created; changes made to
   # the file after that point will not be reflected.
   #
   def initialize(file)
      @file = File.expand_path(file)
      @file = @file.tr('/', "\\")
      @file = multi_to_wide(@file)

      @file_type = get_file_type(@file)
      @chardev = @file_type == FILE_TYPE_CHAR

      case GetDriveTypeW(@file)
         when DRIVE_REMOVABLE, DRIVE_CDROM, DRIVE_RAMDISK
            @blockdev = true
         else
            @blockdev = false
      end
      
      # The stat struct in stat.h only has 11 members on Windows
      stat_buf = [0,0,0,0,0,0,0,0,0,0,0].pack('ISSsssIQQQQ')

      # The stat64 function doesn't seem to like character devices
      if wstat64(@file, stat_buf) != 0
         raise ArgumentError, get_last_error unless @chardev
      end

      # Some bytes skipped (padding for struct alignment)
      @dev   = stat_buf[0, 4].unpack('I').first  # Drive number
      @ino   = stat_buf[4, 2].unpack('S').first  # Meaningless
      @mode  = stat_buf[6, 2].unpack('S').first  # File mode bit mask
      @nlink = stat_buf[8, 2].unpack('s').first  # Always 1
      @uid   = stat_buf[10, 2].unpack('s').first # Always 0
      @gid   = stat_buf[12, 2].unpack('s').first # Always 0
      @rdev  = stat_buf[16, 4].unpack('I').first # Same as dev
      @size  = stat_buf[24, 8].unpack('Q').first # Size of file in bytes
      
      # This portion can fail in rare, FS related instances. If it does, set
      # the various times to Time.at(0).
      begin
         @atime = Time.at(stat_buf[32, 8].unpack('Q').first) # Access time
         @mtime = Time.at(stat_buf[40, 8].unpack('Q').first) # Mod time
         @ctime = Time.at(stat_buf[48, 8].unpack('Q').first) # Creation time
      rescue
         @atime = Time.at(0)
         @mtime = Time.at(0)
         @ctime = Time.at(0)
      end
      
      @mode = 33188 if @chardev

      attributes = GetFileAttributesW(@file)
      error_num  = GetLastError()

      # Locked files.
      if error_num == ERROR_SHARING_VIOLATION
         buffer = 0.chr * 512

         begin
            handle = FindFirstFileW(@file, buffer)

            if handle == INVALID_HANDLE_VALUE
               raise SystemCallError, get_last_error()
            end
         ensure
            FindClose(handle) if handle != INVALID_HANDLE_VALUE
         end

         attributes = buffer[0,4].unpack('L').first
         st = 0.chr * 16
         FileTimeToSystemTime(buffer[4,8],st)
         y,m,w,d,h,n,s,i = st.unpack('SSSSSSSS')
         @ctime = Time.local(y,m,d,h,n,s)
           
         st = 0.chr * 16
         FileTimeToSystemTime(buffer[12,8],st)
         y,m,w,d,h,n,s,i = st.unpack('SSSSSSSS')
         @atime = Time.local(y,m,d,h,n,s)
           
         st = 0.chr * 16
         FileTimeToSystemTime(buffer[20,8],st)
         y,m,w,d,h,n,s,i = st.unpack('SSSSSSSS')
         @mtime = Time.local(y,m,d,h,n,s)
      end

      # Ignore errors caused by empty/open/used block devices.
      if attributes == INVALID_FILE_ATTRIBUTES
         unless error_num == ERROR_NOT_READY
            raise ArgumentError, get_last_error(error_num)
         end
      end
     
     @blksize = get_blksize(@file)
      
      # This is a reasonable guess
      case @blksize
         when nil
            @blocks = nil
         when 0
            @blocks = 0
         else
            @blocks  = (@size.to_f / @blksize.to_f).ceil
      end
      
      @readonly      = attributes & FILE_ATTRIBUTE_READONLY > 0
      @hidden        = attributes & FILE_ATTRIBUTE_HIDDEN > 0
      @system        = attributes & FILE_ATTRIBUTE_SYSTEM > 0
      @archive       = attributes & FILE_ATTRIBUTE_ARCHIVE > 0
      @directory     = attributes & FILE_ATTRIBUTE_DIRECTORY > 0
      @encrypted     = attributes & FILE_ATTRIBUTE_ENCRYPTED > 0
      @normal        = attributes & FILE_ATTRIBUTE_NORMAL > 0
      @temporary     = attributes & FILE_ATTRIBUTE_TEMPORARY > 0
      @sparse        = attributes & FILE_ATTRIBUTE_SPARSE_FILE > 0
      @reparse_point = attributes & FILE_ATTRIBUTE_REPARSE_POINT > 0
      @compressed    = attributes & FILE_ATTRIBUTE_COMPRESSED > 0
      @offline       = attributes & FILE_ATTRIBUTE_OFFLINE > 0
      @indexed       = attributes & ~FILE_ATTRIBUTE_NOT_CONTENT_INDEXED > 0
      
      @executable = GetBinaryTypeW(@file, '')
      @regular    = @file_type == FILE_TYPE_DISK
      @pipe       = @file_type == FILE_TYPE_PIPE
      
      # Not supported and/or meaningless
      @dev_major     = nil
      @dev_minor     = nil
      @grpowned      = true
      @owned         = true
      @readable      = true
      @readable_real = true
      @rdev_major    = nil
      @rdev_minor    = nil
      @setgid        = false
      @setuid        = false
      @sticky        = false
      @symlink       = false
      @writable      = true
      @writable_real = true
   end
   
   ## Comparable
   
   # Compares two File::Stat objects.  Comparsion is based on mtime only.
   #
   def <=>(other)
      @mtime.to_i <=> other.mtime.to_i
   end
   
   ## Miscellaneous
   
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
   
   # Returns whether or not the file is executable.  Generally speaking, this
   # means .bat, .cmd, .com, and .exe files.
   #
   def executable?
      @executable
   end
   
   alias :executable_real? :executable?
   
   # Returns whether or not the file is a regular file, as opposed to a pipe,
   # socket, etc.
   #
   def file?
      @regular
   end
   
   # Identifies the type of file. The return string is one of: file,
   # directory, characterSpecial, socket or unknown.
   #
   def ftype
      return 'directory' if directory?
      case @file_type
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
   
   # Meaningless on Windows.
   #
   def grpowned?
      @grpowned
   end
   
   # Always true on Windows
   def owned?
      @owned
   end
   
   # Returns whether or not the file is a pipe.
   #
   def pipe?
      @pipe
   end
   
   alias :socket? :pipe?
   
   # Meaningless on Windows
   #
   def readable?
      @readable
   end
   
   # Meaningless on Windows
   #
   def readable_real?
      @readable_real
   end
   
   # Meaningless on Windows
   #
   def setgid?
      @setgid
   end
   
   # Meaningless on Windows
   #
   def setuid?
      @setuid
   end
   
   # Returns nil if statfile is a zero-length file; otherwise, returns the
   # file size. Usable as a condition in tests.
   #
   def size?
      @size > 0 ? @size : nil
   end
   
   # Meaningless on Windows.
   #
   def sticky?
      @sticky
   end
   
   # Meaningless on Windows at the moment.  This may change in the future.
   #
   def symlink?
      @symlink
   end
   
   # Meaningless on Windows.
   #
   def writable?
      @writable
   end
   
   # Meaningless on Windows.
   #
   def writable_real?
      @writable_real
   end
   
   # Returns whether or not the file size is zero.
   #
   def zero?
      @size == 0
   end
   
   ## Attribute members
   
   # Returns whether or not the file is an archive file.
   #
   def archive?
      @archive
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
   alias :content_indexed? :indexed?
   
   # Returns whether or not the file is 'normal'.  This is only true if
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
   
   # Returns whether or not the file is readonly.
   #
   def readonly?
      @readonly
   end 

   alias :read_only? :readonly?
   
   # Returns whether or not the file is a reparse point.
   #
   def reparse_point?
      @reparse_point
   end
   
   # Returns whether or not the file is a sparse file.  In most cases a sparse
   # file is an image file.
   #
   def sparse?
      @sparse
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
   
   ## Standard stat members
   
   # Returns a Time object containing the last access time.
   #
   def atime
      @atime
   end
   
   # Returns the file system's block size, or nil if it cannot be determined.
   #
   def blksize
      @blksize
   end
   
   # Returns the number of blocks used by the file, where a block is defined
   # as size divided by blksize, rounded up.
   #
   #--
   # This is a fudge. A search of the internet reveals different ways people
   # have defined st_blocks on MS Windows.
   #
   def blocks
      @blocks
   end
   
   # Returns a Time object containing the time that the file status associated
   # with the file was changed.
   #
   def ctime
      @ctime
   end
   
   # Drive letter (A-Z) of the disk containing the file.  If the path is a
   # UNC path then the drive number (probably -1) is returned instead.
   #
   def dev
      if PathIsUNCW(@file)
         @dev
      else
         (@dev + ?A).chr + ':'
      end
   end
   
   # Group ID. Always 0.
   #
   def gid
      @gid
   end
   
   # Inode number. Meaningless on NTFS.
   #
   def ino
      @ino
   end
   
   # Bit mask for file-mode information.
   #
   # :no-doc:
   # This was taken from rb_win32_stat() in win32.c.  I'm not entirely
   # sure what the point is.
   #
   def mode
      @mode &= ~(S_IWGRP | S_IWOTH)
   end
   
   # Returns a Time object containing the modification time.
   #
   def mtime
      @mtime
   end

   # Drive number of the disk containing the file.
   #
   def rdev
      @rdev
   end
   
   # Always 1
   #
   def nlink
      @nlink
   end
   
   # Returns the size of the file, in bytes.
   #
   def size
      @size
   end
   
   # User ID. Always 0.
   #
   def uid
      @uid
   end
   
   # Returns a stringified version of a File::Stat object.
   #
   def inspect    
      members = %w/
         archive? atime blksize blockdev? blocks compressed? ctime dev
         encrypted? gid hidden? indexed? ino mode mtime rdev nlink normal?
         offline? readonly? reparse_point? size sparse? system? temporary?
         uid
      /
      str = "#<#{self.class}"
      members.sort.each{ |mem|
         if mem == 'mode'
            str << " #{mem}=" << sprintf("0%o", send(mem.intern))
         elsif mem[-1].chr == '?'
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
      members = %w/
         archive? atime blksize blockdev? blocks compressed? ctime dev
         encrypted? gid hidden? indexed? ino mode mtime rdev nlink normal?
         offline? readonly? reparse_point? size sparse? system? temporary?
         uid
      /

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
   
   # Since old_init was added strictly to avoid a warning, we remove it now.
   remove_method(:old_init)
   
   private
   
   # Returns the file system's block size.
   #
   def get_blksize(file)
      size = nil
   
      sectors = [0].pack('L')
      bytes   = [0].pack('L')
      free    = [0].pack('L')
      total   = [0].pack('L')
      
      # If there's a drive letter it must contain a trailing backslash.
      # The dup is necessary here because the function modifies the argument.
      file = file.dup
      
      if PathStripToRootA(wide_to_multi(file))
         file = file[/^[^\0]*/] << ':'
         file << "\\" unless file[-1].chr == "\\"
      else
         file = nil # Default to the root drive on relative paths
      end
      
      # Don't check for an error here.  Just default to nil.
      if GetDiskFreeSpaceA(file, sectors, bytes, free, total)
         size = sectors.unpack('L').first * bytes.unpack('L').first
      end
      
      size
   end
   
   # Private method to get a HANDLE when CreateFile() won't cut it.
   #
   def get_handle(file)
      file = file.upcase

      begin
         hdlTokenHandle = 0.chr * 4

         OpenProcessToken(
            GetCurrentProcess(),
            TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
            hdlTokenHandle
         )

         hdlTokenHandle = hdlTokenHandle.unpack('L').first

         # Get the LUID for shutdown privilege.
         tmpLuid = 0.chr * 8
         LookupPrivilegeValue("", "SeDebugPrivilege", tmpLuid)
         tkp = [1].pack('L') + tmpLuid + [SE_PRIVILEGE_ENABLED].pack('L')

         # Enable the shutdown privilege in the access token of this process.
         AdjustTokenPrivileges(hdlTokenHandle, 0,tkp, tkp.length , nil, nil)
      ensure
         CloseHandle(hdlTokenHandle)
      end
      
      # First call is to get the required length
      handle_info = 0.chr * 4096
      required = 0.chr * 4
      NtQuerySystemInformation(16, handle_info, 4096, required)

      # Second call is the actual call
      handle_info = 0.chr * required.unpack('L').first
      NtQuerySystemInformation(16, handle_info, handle_info.length, required)

      count = handle_info[0,4].unpack('L').first

      for i in 0...count
         pid, type, handle, addr, access = handle_info[4+i*16,16].unpack('LSSLL')
         if access & 0xffff == 3
            begin
               process = OpenProcess(0x40,1,pid)
               dup_handle = 0.chr * 4

               DuplicateHandle(
                  process,
                  handle,
                  GetCurrentProcess(),
                  dup_handle,
                  0,
                  1,
                  2
               )
            ensure
               CloseHandle(process)
            end

            handle = dup_handle.unpack('L').first
            buffer = 0.chr * 0x2000
            NtQueryObject(handle, 1, buffer, 0x2000, nil)
            len = buffer[0,2].unpack('S').first

            if len>0
               if buffer[8..-1].upcase[file]
                  return handle
               end
            end
            CloseHandle(handle)
         end
      end

      return 0
   end
   
   # Returns the file's type (as a numeric).
   #
   def get_file_type(file)
      begin
         handle = CreateFileW(
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

   private
   
   # Verifies that a value is either true or false
   def check_bool(val)
      raise TypeError unless val == true || val == false
   end
end