#####################################################################
# test_file_stat.rb
#
# Test case for stat related methods of win32-file. You should use
# the 'rake test' task to run these tests.
#####################################################################
require 'etc'
require 'ffi'
require 'test-unit'
require 'win32/file/stat'
require 'win32/security'
require 'pathname'

class TC_Win32_File_Stat < Test::Unit::TestCase
  extend FFI::Library
  ffi_lib :kernel32

  attach_function :GetDriveType, :GetDriveTypeA, [:string], :ulong
  attach_function :GetFileAttributes, :GetFileAttributesA, [:string], :ulong
  attach_function :SetFileAttributes, :SetFileAttributesA, [:string, :ulong], :bool

  DRIVE_REMOVABLE = 2
  DRIVE_CDROM     = 5
  DRIVE_RAMDISK   = 6

  def self.startup
    @@block_dev = nil

    'A'.upto('Z'){ |volume|
      volume += ":\\"
      case GetDriveType(volume)
      when DRIVE_REMOVABLE, DRIVE_CDROM, DRIVE_RAMDISK
        @@block_dev = volume
        break
      end
    }

    @@txt_file = File.join(File.expand_path(File.dirname(__FILE__)), 'test_file.txt')
    @@exe_file = File.join(File.expand_path(File.dirname(__FILE__)), 'test_file.exe')
    @@sys_file = 'C:/pagefile.sys'
    @@elevated = Win32::Security.elevated_security?
    @@jruby    = RUBY_PLATFORM == 'java'

    File.open(@@txt_file, "w"){ |fh| fh.print "This is a test\nHello" }
    File.open(@@exe_file, "wb"){ |fh| fh.print "This is a test" }
  end

  def setup
    @dir  = Dir.pwd
    @stat = File::Stat.new(@@txt_file)
    @temp = 'win32_file_stat.tmp'
    File.open(@temp, 'w'){}
    @attr = GetFileAttributes(@@txt_file)
  end

  test "version is set to expected value" do
    assert_equal('1.4.2', File::Stat::WIN32_FILE_STAT_VERSION)
  end

  test "constructor does not modify argument" do
    expected = File.join(File.expand_path(File.dirname(__FILE__)), 'test_file.txt')
    File::Stat.new(@@txt_file)
    assert_equal(expected, @@txt_file)
  end

  test "constructor allows arguments that implement to_path" do
    assert_nothing_raised{ File::Stat.new(Pathname.new(Dir.pwd)) }
  end

  test "archive? method basic functionality" do
    assert_respond_to(@stat, :archive?)
    assert_nothing_raised{ @stat.archive? }
  end

  test "archive? method returns a boolean value" do
    assert_boolean(@stat.archive?)
  end

  test "atime method basic functionality" do
    assert_respond_to(@stat, :atime)
    assert_nothing_raised{ @stat.atime }
  end

  test "atime method returns expected value" do
    assert_kind_of(Time, @stat.atime)
    assert_true(@stat.atime.to_i > 0)
  end

  test "mtime method basic functionality" do
    assert_respond_to(@stat, :mtime)
    assert_nothing_raised{ @stat.mtime }
  end

  test "mtime method returns expected value" do
    assert_kind_of(Time, @stat.mtime)
    assert_true(@stat.mtime.to_i > 0)
  end

  test "ctime method basic functionality" do
    assert_respond_to(@stat, :ctime)
    assert_nothing_raised{ @stat.ctime }
  end

  test "ctime method returns expected value" do
    assert_kind_of(Time, @stat.ctime)
    assert_true(@stat.ctime.to_i > 0)
  end

  test "blksize basic functionality" do
    assert_respond_to(@stat, :blksize)
    assert_kind_of(Fixnum, @stat.blksize)
  end

  test "blksize returns expected value" do
    assert_equal(4096, @stat.blksize)
    assert_equal(4096, File::Stat.new("C:\\").blksize)
  end

  test "blockdev? basic functionality" do
    assert_respond_to(@stat, :blockdev?)
    assert_boolean(@stat.blockdev?)
  end

  test "blockdev? returns the expected value for a non-block device" do
    assert_false(@stat.blockdev?)
    assert_false(File::Stat.new('NUL').blockdev?)
  end

  # In unusual situations this could fail.
  test "blockdev? returns the expected value for a block device" do
    omit_unless(@@block_dev)
    assert_true(File::Stat.new(@@block_dev).blockdev?)
  end

  test "blocks basic functionality" do
    assert_respond_to(@stat, :blocks)
    assert_kind_of(Fixnum, @stat.blocks)
  end

  test "blocks method returns expected value" do
    assert_equal(1, @stat.blocks)
  end

  test "chardev? custom method basic functionality" do
    assert_respond_to(@stat, :chardev?)
    assert_boolean(@stat.chardev?)
  end

  test "chardev? custom method returns expected value" do
    assert_true(File::Stat.new("NUL").chardev?)
    assert_false(File::Stat.new("C:\\").chardev?)
  end

  test "custom comparison method basic functionality" do
    assert_respond_to(@stat, :<=>)
    assert_nothing_raised{ @stat <=> File::Stat.new(@@exe_file) }
  end

  test "custom comparison method works as expected" do
    assert_equal(0, @stat <=> @stat)
  end

  test "compressed? basic functionality" do
    assert_respond_to(@stat, :compressed?)
    assert_boolean(@stat.compressed?)
  end

  test "compressed? returns expected value" do
    assert_false(@stat.compressed?)
  end

  test "dev custom method basic functionality" do
    assert_respond_to(@stat, :rdev)
    assert_kind_of(Numeric, @stat.rdev)
  end

  test "dev custom method returns expected value" do
    notify "May fail on JRuby" if @@jruby
    assert_equal(2, File::Stat.new("C:\\").dev)
    assert_equal(-1, File::Stat.new("NUL").dev)
  end

  test "dev custom method accepts an optional argument" do
    assert_nothing_raised{ File::Stat.new("C:\\").dev(true) }
    assert_kind_of(String, File::Stat.new("C:\\").dev(true))
  end

  test "dev custom method with optional argument returns expected value" do
    notify "May fail on JRuby" if @@jruby
    assert_equal("C:", File::Stat.new("C:\\").dev(true))
    assert_nil(File::Stat.new("NUL").dev(true))
  end

  test "dev_major defined and always returns nil" do
    omit_if(@@jruby) # https://github.com/jnr/jnr-posix/issues/23
    assert_respond_to(@stat, :dev_major)
    assert_nil(@stat.dev_major)
  end

  test "dev_minor defined and always returns nil" do
    omit_if(@@jruby) # https://github.com/jnr/jnr-posix/issues/23
    assert_respond_to(@stat, :dev_minor)
    assert_nil(@stat.dev_minor)
  end

  test "directory? custom method basic functionality" do
    assert_respond_to(@stat, :directory?)
    assert_boolean(@stat.directory?)
  end

  test "directory? custom method returns expected value" do
    assert_false(@stat.directory?)
    assert_true(File::Stat.new("C:\\").directory?)
  end

  test "executable? custom method basic functionality" do
    assert_respond_to(@stat, :executable?)
    assert_boolean(@stat.executable?)
  end

  test "executable? custom method returns expected value" do
    assert_false(@stat.executable?)
    assert_true(File::Stat.new(@@exe_file).executable?)
  end

  test "executable_real? is an alias for executable?" do
    assert_respond_to(@stat, :executable_real?)
    assert_alias_method(@stat, :executable?, :executable_real?)
  end

  test "file? custom method basic functionality" do
    assert_respond_to(@stat, :file?)
    assert_boolean(@stat.file?)
  end

  test "file? custom method returns expected value" do
    assert_true(@stat.file?)
    assert_true(File::Stat.new(@@exe_file).file?)
    assert_true(File::Stat.new(Dir.pwd).file?)
    assert_false(File::Stat.new('NUL').file?)
  end

  test "ftype custom method basic functionality" do
    assert_respond_to(@stat, :ftype)
    assert_kind_of(String, @stat.ftype)
  end

  test "ftype custom method returns expected value" do
    assert_equal('file', @stat.ftype)
    assert_equal('characterSpecial', File::Stat.new('NUL').ftype)
    assert_equal('directory', File::Stat.new(Dir.pwd).ftype)
  end

  test "encrypted? basic functionality" do
    assert_respond_to(@stat, :encrypted?)
    assert_boolean(@stat.encrypted?)
  end

  test "encrypted? returns the expected value" do
    assert_false(@stat.encrypted?)
  end

  test "gid method basic functionality" do
    assert_respond_to(@stat, :gid)
    assert_nothing_raised{ @stat.gid }
    assert_kind_of(Fixnum, @stat.gid)
  end

  test "gid returns a sane result" do
    assert_true(@stat.gid >= 0 && @stat.gid <= 10000)
  end

  test "gid returns a string argument if true argument provided" do
    assert_nothing_raised{ @stat.gid(true) }
    assert_match("S-1-", @stat.gid(true))
  end

  test "grpowned? defined and always returns true" do
    assert_respond_to(@stat, :grpowned?)
  end

  test "hidden? basic functionality" do
    assert_respond_to(@stat, :hidden?)
    assert_boolean(@stat.hidden?)
  end

  test "hidden? returns expected value" do
    assert_false(@stat.hidden?)
  end

  test "indexed? basic functionality" do
    assert_respond_to(@stat, :indexed?)
    assert_boolean(@stat.indexed?)
  end

  test "indexed? returns expected value" do
    assert_true(@stat.indexed?)
  end

  test "content_indexed? is an alias for indexed?" do
    assert_respond_to(@stat, :content_indexed?)
    assert_alias_method(@stat, :indexed?, :content_indexed?)
  end

  test "ino method basic functionality" do
    assert_respond_to(@stat, :ino)
    assert_nothing_raised{ @stat.ino }
    assert_kind_of(Numeric, @stat.ino)
  end

  test "ino method returns a sane value" do
    assert_true(@stat.ino > 1000)
  end

  test "ino method returns nil on a special device" do
    assert_nil(File::Stat.new("NUL").ino)
  end

  test "inspect custom method basic functionality" do
    assert_respond_to(@stat, :inspect)
  end

  test "inspect string contains expected values" do
    assert_match('File::Stat', @stat.inspect)
    assert_match('compressed', @stat.inspect)
    assert_match('normal', @stat.inspect)
  end

  test "mode custom method basic functionality" do
    assert_respond_to(@stat, :mode)
    assert_kind_of(Fixnum, @stat.mode)
  end

  test "mode custom method returns the expected value" do
    assert_equal(33188, File::Stat.new(@@txt_file).mode)
    assert_equal(33261, File::Stat.new(@@exe_file).mode)
    assert_equal(16877, File::Stat.new(@dir).mode)
  end

  test "mode custom method returns expected value for readonly file" do
    SetFileAttributes(@@txt_file, 1) # Set to readonly.
    assert_equal(33060, File::Stat.new(@@txt_file).mode)
  end

  test "nlink basic functionality" do
    assert_respond_to(@stat, :nlink)
    assert_kind_of(Fixnum, @stat.nlink)
  end

  test "nlink returns the expected value" do
    assert_equal(1, @stat.nlink)
    assert_equal(1, File::Stat.new(Dir.pwd).nlink)
    assert_equal(1, File::Stat.new('NUL').nlink)
  end

  test "normal? basic functionality" do
    assert_respond_to(@stat, :normal?)
    assert_boolean(@stat.normal?)
  end

  test "normal? returns expected value" do
    assert_false(@stat.normal?)
  end

  test "offline? method basic functionality" do
    assert_respond_to(@stat, :offline?)
    assert_boolean(@stat.offline?)
  end

  test "offline? method returns expected value" do
    assert_false(@stat.offline?)
  end

  test "owned? method basic functionality" do
    assert_respond_to(@stat, :owned?)
    assert_boolean(@stat.owned?)
  end

  test "owned? returns the expected results" do
    if @@elevated
      assert_false(@stat.owned?)
    else
      assert_true(@stat.owned?)
    end
    assert_false(File::Stat.new(@@sys_file).owned?)
  end

  test "pipe? custom method basic functionality" do
    assert_respond_to(@stat, :pipe?)
    assert_boolean(@stat.pipe?)
  end

  test "pipe? custom method returns expected value" do
    assert_false(@stat.pipe?)
  end

  test "socket? is an alias for pipe?" do
    assert_respond_to(@stat, :socket?)
    assert_alias_method(@stat, :socket?, :pipe?)
  end

  test "readable? basic functionality" do
    assert_respond_to(@stat, :readable?)
    assert_boolean(@stat.readable?)
  end

  test "readable? returns expected value" do
    assert_true(@stat.readable?)
    assert_true(File::Stat.new(Dir.pwd).readable?)
    assert_false(File::Stat.new(@@sys_file).readable?)
  end

  test "readable_real? basic functionality" do
    assert_respond_to(@stat, :readable_real?)
    assert_boolean(@stat.readable_real?)
  end

  test "readable_real? returns expected value" do
    assert_true(@stat.readable_real?)
  end

  test "readonly? basic functionality" do
    assert_respond_to(@stat, :readonly?)
    assert_boolean(@stat.readonly?)
  end

  test "readonly? returns the expected value" do
    assert_false(@stat.readonly?)
    SetFileAttributes(@@txt_file, 1)
    assert_true(File::Stat.new(@@txt_file).readonly?)
  end

  test "read_only? is an alias for readonly?" do
    assert_respond_to(@stat, :read_only?)
    assert_alias_method(@stat, :readonly?, :read_only?)
  end

  test "reparse_point? basic functionality" do
    assert_respond_to(@stat, :reparse_point?)
    assert_boolean(@stat.reparse_point?)
  end

  test "reparse_point returns expected value" do
    assert_false(@stat.reparse_point?)
  end

  test "rdev basic functionality" do
    assert_respond_to(@stat, :rdev)
    assert_nothing_raised{ @stat.rdev }
    assert_kind_of(Numeric, @stat.rdev)
  end

  test "rdev returns a sane value" do
    assert_true(File::Stat.new("C:\\Program Files").rdev > 1000)
  end

  test "rdev returns nil on special files" do
    assert_equal(nil, File::Stat.new("NUL").rdev)
  end

  # Not sure how to test properly in a generic way, but works on my local network
  test "rdev works on unc path" do
    omit_unless(Etc.getlogin == "djberge" && File.exist?("//scipio/users"))
    assert_true(File::Stat.new("//scipio/users").rdev > 1000)
  end

  test "rdev_major defined and always returns nil" do
    omit_if(@@jruby) # https://github.com/jnr/jnr-posix/issues/23
    assert_respond_to(@stat, :rdev_major)
    assert_nil(@stat.rdev_major)
  end

  test "rdev_minor defined and always returns nil" do
    omit_if(@@jruby) # https://github.com/jnr/jnr-posix/issues/23
    assert_respond_to(@stat, :rdev_minor)
    assert_nil(@stat.rdev_minor)
  end

  test "setgid is set to false" do
    assert_respond_to(@stat, :setgid?)
    assert_false(@stat.setgid?)
  end

  test "setuid is set to false" do
    assert_respond_to(@stat, :setuid?)
    assert_false(@stat.setuid?)
  end

  test "size custom method basic functionality" do
    assert_respond_to(@stat, :size)
    assert_kind_of(Numeric, @stat.size)
  end

  test "size custom method returns expected value" do
    assert_equal(21, @stat.size)
    @stat = File::Stat.new(@temp)
    assert_equal(0, @stat.size)
  end

  test "size custom method works on system files" do
    assert_nothing_raised{ File::Stat.new(@@sys_file).size }
  end

  test "size? method basic functionality" do
    assert_respond_to(@stat, :size?)
    assert_kind_of(Numeric, @stat.size)
  end

  test "size? method returns integer if size greater than zero" do
    assert_equal(21, @stat.size?)
  end

  test "size? method returns nil if size is zero" do
    @stat = File::Stat.new(@temp)
    assert_nil(@stat.size?)
  end

  test "sparse? basic fucntionality" do
    assert_respond_to(@stat, :sparse?)
    assert_boolean(@stat.sparse?)
  end

  test "sparse? returns expected value" do
    assert_false(@stat.sparse?)
  end

  test "sticky is always set to false" do
    assert_respond_to(@stat, :sticky?)
    assert_false(@stat.sticky?)
  end

  test "symlink? basic functionality" do
    assert_respond_to(@stat, :symlink?)
    assert_boolean(@stat.symlink?)
  end

  test "symlink? returns expected value" do
    assert_false(@stat.symlink?)
  end

  test "system? basic functionality" do
    assert_respond_to(@stat, :system?)
    assert_boolean(@stat.system?)
  end

  test "system? returns expected value" do
    assert_false(@stat.system?)
  end

  test "temporary? basic functionality" do
    assert_respond_to(@stat, :temporary?)
    assert_boolean(@stat.temporary?)
  end

  test "temporary? returns expected value" do
    assert_false(@stat.temporary?)
  end

  test "uid basic functionality" do
    assert_respond_to(@stat, :uid)
    assert_nothing_raised{ @stat.uid }
    assert_kind_of(Fixnum, @stat.uid)
  end

  test "uid returns a sane result" do
    assert_true(@stat.uid >= 0 && @stat.uid <= 10000)
  end

  test "uid returns a string argument if true argument provided" do
    assert_nothing_raised{ @stat.uid(true) }
    assert_match("S-1-", @stat.uid(true))
  end

  test "world_readable? basic functionality" do
    assert_respond_to(@stat, :world_readable?)
    assert_boolean(@stat.world_readable?)
  end

  # TODO: Find or create a file that returns true.
  test "world_readable? returns expected result" do
    assert_false(@stat.world_readable?)
    assert_false(File::Stat.new("C:/").world_readable?)
  end

  test "world_writable? basic functionality" do
    assert_respond_to(@stat, :world_writable?)
    assert_boolean(@stat.world_writable?)
  end

  # TODO: Find or create a file that returns true.
  test "world_writable? returns expected result" do
    assert_false(@stat.world_writable?)
    assert_false(File::Stat.new("C:/").world_writable?)
  end

  test "writable? basic functionality" do
    assert_respond_to(@stat, :writable?)
    assert_boolean(@stat.writable?)
  end

  test "writable? returns expected value" do
    assert_true(@stat.writable?)
    assert_true(File::Stat.new(Dir.pwd).writable?)
    assert_false(File::Stat.new(@@sys_file).writable?)
  end

  test "a file marked as readonly is not considered writable" do
    File.chmod(0644, @@txt_file)
    assert_true(File::Stat.new(@@txt_file).writable?)
    File.chmod(0444, @@txt_file)
    assert_false(File::Stat.new(@@txt_file).writable?)
  end

  test "writable_real? basic functionality" do
    assert_respond_to(@stat, :writable_real?)
    assert_boolean(@stat.writable_real?)
  end

  test "writable_real? returns expected value" do
    assert_true(@stat.writable_real?)
  end

  test "zero? method basic functionality" do
    assert_respond_to(@stat, :zero?)
    assert_boolean(@stat.zero?)
  end

  test "zero? method returns expected value" do
    assert_false(@stat.zero?)
    @stat = File::Stat.new(@temp)
    assert_true(@stat.zero?)
  end

  test "ffi functions are private" do
    assert_not_respond_to(@stat, :CloseHandle)
    assert_not_respond_to(File::Stat, :CloseHandle)
  end

  def teardown
    SetFileAttributes(@@txt_file, @attr) # Set file back to normal
    File.delete(@temp) if File.exist?(@temp)
    @dir  = nil
    @stat = nil
    @attr = nil
    @temp = nil
  end

  def self.shutdown
    File.delete(@@txt_file) if File.exist?(@@txt_file)
    File.delete(@@exe_file) if File.exist?(@@exe_file)

    @@block_dev = nil
    @@txt_file  = nil
    @@exe_file  = nil
    @@sys_file  = nil
    @@elevated  = nil
    @@jruby     = nil
  end
end
