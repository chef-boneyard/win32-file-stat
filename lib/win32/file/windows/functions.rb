require 'ffi'

module Windows
  module Functions
    extend FFI::Library

    typedef :ulong, :dword
    typedef :uintptr_t, :handle
    typedef :pointer, :ptr
    typedef :buffer_in, :buf_in

    ffi_lib :kernel32

    attach_function :FindFirstFile, :FindFirstFileW, [:buf_in, :ptr], :handle
    attach_function :FindNextFile, :FindNextFileW, [:buf_in, :ptr], :bool
    attach_function :FindClose, [:handle], :bool
    attach_function :GetDiskFreeSpace, :GetDiskFreeSpaceW, [:buf_in, :ptr, :ptr, :ptr, :ptr], :bool

    ffi_lib :shlwapi

    attach_function :PathStripToRoot, :PathStripToRootW, [:ptr], :bool
  end
end
