require 'ffi'

module Windows
  module Functions
    extend FFI::Library

    typedef :ulong, :dword
    typedef :uintptr_t, :handle
    typedef :pointer, :ptr
    typedef :buffer_in, :buf_in
    typedef :string, :str

    ffi_lib :kernel32

    attach_function :FindFirstFileA, [:string, :ptr], :handle
    attach_function :FindNextFileA, [:handle, :ptr], :bool
    attach_function :FindClose, [:handle], :bool

    attach_function :GetDiskFreeSpaceA, [:str, :ptr, :ptr, :ptr, :ptr], :bool
    attach_function :GetDriveTypeA, [:str], :uint

    ffi_lib :shlwapi

    attach_function :PathStripToRootA, [:ptr], :bool
    attach_function :PathRemoveBackslashA, [:buffer_out], :string
    attach_function :PathIsRootA, [:str], :bool
  end
end
