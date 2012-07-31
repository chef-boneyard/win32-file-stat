#####################################################################
# test_file_stat.rb
#
# Test case for stat related methods of win32-file. You should use
# the 'rake test' task to run these tests.
#####################################################################
require 'ffi'
require 'test-unit'
require 'win32/file/stat'

class TC_Win32_File_Stat < Test::Unit::TestCase
  extend FFI::Library
  ffi_lib :kernel32

  attach_function :GetDriveType, :GetDriveTypeA, [:string], :ulong

  DRIVE_REMOVABLE = 2
  DRIVE_CDROM     = 5
  DRIVE_RAMDISK   = 6

  def self.startup
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

    File.open(@@txt_file, "w"){ |fh| fh.print "This is a test\nHello" }
    File.open(@@exe_file, "wb"){ |fh| fh.print "This is a test" }
  end

  def setup
    @dir  = Dir.pwd
    @stat = File::Stat.new(@@txt_file)
    #@attr = GetFileAttributes(@@txt_file)
  end

  test "version is set to expected value" do
    assert_equal('1.4.0', File::Stat::VERSION)
  end

  #test "constructor does not modify argument" do
  #  expected = File.join(File.expand_path(File.dirname(__FILE__)), 'test_file.txt')
  #  File::Stat.new(@@txt_file)
  #  assert_equal(expected, @@txt_file)
  #end

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
    assert_respond_to(@stat, :atime)
    assert_nothing_raised{ @stat.atime }
  end

  test "mtime method returns expected value" do
    assert_kind_of(Time, @stat.atime)
    assert_true(@stat.atime.to_i > 0)
  end

  test "ctime method basic functionality" do
    assert_respond_to(@stat, :atime)
    assert_nothing_raised{ @stat.atime }
  end

  test "ctime method returns expected value" do
    assert_kind_of(Time, @stat.atime)
    assert_true(@stat.atime.to_i > 0)
  end

  test "blksize basic functionality" do
    assert_respond_to(@stat, :blksize)
    assert_kind_of(Fixnum, @stat.blksize)
  end

  test "blksize returns expected value" do
    assert_equal(4096, @stat.blksize)
    assert_equal(4096, File::Stat.new("C:\\").blksize)
  end

  test "blockdev basic functionality" do
    assert_respond_to(@stat, :blockdev?)
    assert_boolean(@stat.blockdev?)
  end

  # The block dev test error out if there's no media in it.
  test "blockdev returns the expected results" do
    assert_false(@stat.blockdev?)
    assert_false(File::Stat.new('NUL').blockdev?)

    begin
      assert_true(File::Stat.new(@@block_dev).blockdev?)
    rescue StandardError, SystemCallError
      omit("Skipping because drive is empty or not found")
    end
  end

  test "blocks method basic functionality" do
    assert_respond_to(@stat, :blocks)
    assert_kind_of(Fixnum, @stat.blocks)
  end

  test "blocks method returns the expected value" do
    assert_equal(1, @stat.blocks)
  end

=begin
  test "chardev? basic functionality" do
    assert_respond_to(@stat, :chardev?)
    assert_boolean(@stat.chardev?)
  end

  test "chardev? returns the expected boolean value" do
    assert_false(@stat.chardev?)
    assert_true(File::Stat.new('NUL').chardev?)
    assert_false(File::Stat.new('C:/').chardev?)
  end
=end

=begin
   def test_comparison
      assert_respond_to(@stat, :<=>)
      assert_nothing_raised{ @stat <=> File::Stat.new(@@exe_file) }
   end
=end
  test "compressed? method basic functionality" do
    assert_respond_to(@stat, :compressed?)
    assert_nothing_raised{ @stat.compressed? }
  end

  test "compressed? method returns a boolean value" do
    assert_boolean(@stat.compressed?)
  end

=begin
   # Assumes you've installed on C: drive.
   def test_dev
      assert_respond_to(@stat, :dev)
      assert_equal('C:', @stat.dev)
   end

   def test_dev_major
      assert_respond_to(@stat, :dev_major)
      assert_nil(@stat.dev_major)
   end

   def test_dev_minor
      assert_respond_to(@stat, :dev_minor)
      assert_nil(@stat.dev_minor)
   end
=end
  test "directory? method basic functionality" do
    assert_respond_to(@stat, :directory?)
    assert_nothing_raised{ @stat.directory? }
    assert_boolean(@stat.directory?)
  end

  test "directory? returns the expected result" do
    assert_false(@stat.directory?)
    assert_true(File::Stat.new("C:\\").directory?)
  end

=begin
   def test_executable
      assert_respond_to(@stat, :executable?)
      assert_equal(false, @stat.executable?)
      assert_equal(true, File::Stat.new(@@exe_file).executable?)
   end

   def test_executable_real
      assert_respond_to(@stat, :executable_real?)
      assert_equal(false, @stat.executable_real?)
      assert_equal(true, File::Stat.new(@@exe_file).executable_real?)
   end

   def test_file
      assert_respond_to(@stat, :file?)
      assert_equal(true, @stat.file?)
      assert_equal(true, File::Stat.new(@@exe_file).file?)
      assert_equal(true, File::Stat.new(Dir.pwd).file?)
      assert_equal(false, File::Stat.new('NUL').file?)
   end

   def test_ftype
      assert_respond_to(@stat, :ftype)
      assert_equal('file', @stat.ftype)
      assert_equal('characterSpecial', File::Stat.new('NUL').ftype)
      assert_equal('directory', File::Stat.new(Dir.pwd).ftype)
   end
=end

  test "encrypted? method basic functionality" do
    assert_respond_to(@stat, :encrypted?)
    assert_nothing_raised{ @stat.encrypted? }
    assert_boolean(@stat.encrypted?)
  end

  test "encrypted? returns the expected result" do
    assert_false(@stat.encrypted?)
  end

=begin
   def test_gid
      assert_respond_to(@stat, :gid)
      assert_equal(0, @stat.gid)
   end

   def test_grpowned
      assert_respond_to(@stat, :grpowned?)
   end
=end
  test "hidden? method basic functionality" do
    assert_respond_to(@stat, :hidden?)
    assert_nothing_raised{ @stat.hidden? }
    assert_boolean(@stat.hidden?)
  end

  test "hidden? returns the expected result" do
    assert_false(@stat.hidden?)
  end

  test "indexed? method basic functionality" do
    assert_respond_to(@stat, :indexed?)
    assert_nothing_raised{ @stat.indexed? }
    assert_true(@stat.indexed?)
  end

  test "content_indexed? is an alias for indexed?" do
    assert_alias_method(@stat, :content_indexed?, :indexed?)
  end

=begin
   def test_ino
      assert_respond_to(@stat, :ino)
      assert_equal(0, @stat.ino)
   end

   def test_inspect
      assert_respond_to(@stat, :inspect)
   end

   def test_mode
      assert_respond_to(@stat, :mode)
      assert_equal(33188, File::Stat.new(@@txt_file).mode)
      assert_equal(33261, File::Stat.new(@@exe_file).mode)
      assert_equal(16877, File::Stat.new(@dir).mode)

      SetFileAttributes(@@txt_file, 1) # Set to readonly.
      assert_equal(33060, File::Stat.new(@@txt_file).mode)
   end

   def test_nlink
      assert_respond_to(@stat, :nlink)
      assert_equal(1, @stat.nlink)
   end
=end
  
  test "normal? method basic functionality" do
    assert_respond_to(@stat, :normal?)
    assert_nothing_raised{ @stat.normal? }
  end

  test "normal? method returns a boolean value" do
    assert_boolean(@stat.normal?)
  end

  test "offline? method basic functionality" do
    assert_respond_to(@stat, :offline?)
    assert_nothing_raised{ @stat.offline? }
  end

  test "offline? method returns a boolean value" do
    assert_boolean(@stat.offline?)
  end
=begin
   def test_pipe
      assert_respond_to(@stat, :pipe?)
      assert_equal(false, @stat.pipe?)
   end

   def test_readable
      assert_respond_to(@stat, :readable?)
      assert_equal(true, @stat.readable?)
   end

   def test_readable_real
      assert_respond_to(@stat, :readable_real?)
      assert_equal(true, @stat.readable_real?)
   end

   def test_readonly
      assert_respond_to(@stat, :readonly?)
      assert_nothing_raised{ @stat.readonly? }
      assert_equal(false, @stat.readonly?)
   end

   def test_reparse_point
      assert_respond_to(@stat, :reparse_point?)
      assert_nothing_raised{ @stat.reparse_point? }
      assert_equal(false, @stat.reparse_point?)
   end

   # Assumes you've installed on C: drive.
   def test_rdev
      msg = "ignore failure if Ruby is not installed on C: drive"
      assert_respond_to(@stat, :rdev)
      assert_equal(2, @stat.rdev, msg)
   end

   def test_setgid
      assert_respond_to(@stat, :setgid?)
      assert_equal(false, @stat.setgid?)
   end

   def test_setuid
      assert_respond_to(@stat, :setuid?)
      assert_equal(false, @stat.setuid?)
   end

   def test_size
      assert_respond_to(@stat, :size)
      assert_equal(21, @stat.size)
   end

   def test_size_system_file
      omit_if(windows_64?, 'skipping system file test on 64-bit OS')
      assert_nothing_raised{ File::Stat.new(@@sys_file).size }
   end

   def test_size_bool
      assert_respond_to(@stat, :size?)
      assert_equal(21, @stat.size?)
   end

   def test_socket
      assert_respond_to(@stat, :socket?)
      assert_equal(false, @stat.socket?)
   end

   def test_sparse
      assert_respond_to(@stat, :sparse?)
      assert_nothing_raised{ @stat.sparse? }
      assert_equal(false, @stat.sparse?)
   end

   def test_sticky
      assert_respond_to(@stat, :sticky?)
      assert_equal(false, @stat.sticky?)
   end

   def test_symlink
      assert_respond_to(@stat, :symlink?)
      assert_equal(false, @stat.symlink?)
   end

   def test_system
      assert_respond_to(@stat, :system?)
      assert_nothing_raised{ @stat.system? }
      assert_equal(false, @stat.system?)
   end

   def test_temporary
      assert_respond_to(@stat, :temporary?)
      assert_nothing_raised{ @stat.temporary? }
      assert_equal(false, @stat.temporary?)
   end

   def test_uid
      assert_respond_to(@stat, :uid)
      assert_equal(0, @stat.uid)
   end

   def test_writable
      assert_respond_to(@stat, :writable?)
      assert_equal(true, @stat.writable?)
   end

   def test_writable_real
      assert_respond_to(@stat, :writable_real?)
      assert_equal(true, @stat.writable_real?)
   end

   def test_zero
      assert_respond_to(@stat, :zero?)
      assert_equal(false, @stat.zero?)
   end
=end

  def teardown
    #SetFileAttributes(@@txt_file, @attr) # Set file back to normal
    @dir  = nil
    @stat = nil
    @attr = nil
  end

  def self.shutdown
    File.delete(@@txt_file) if File.exists?(@@txt_file)
    File.delete(@@exe_file) if File.exists?(@@exe_file)

    @@block_dev = nil
    @@txt_file  = nil
    @@exe_file  = nil
    @@sys_file  = nil
  end
end
