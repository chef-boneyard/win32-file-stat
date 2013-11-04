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
    ffi_convention :stdcall

    attach_function :CloseHandle, [:handle], :bool
    attach_function :CreateFile, :CreateFileA, [:str, :dword, :dword, :ptr, :dword, :dword, :handle], :handle
    attach_function :FindFirstFile, :FindFirstFileA, [:string, :ptr], :handle
    attach_function :FindClose, [:handle], :bool

    attach_function :GetDiskFreeSpace, :GetDiskFreeSpaceA, [:str, :ptr, :ptr, :ptr, :ptr], :bool
    attach_function :GetDriveType, :GetDriveTypeA, [:str], :uint
    attach_function :GetFileInformationByHandle, [:handle, :ptr], :bool
    attach_function :GetFileType, [:handle], :dword

    ffi_lib :shlwapi

    attach_function :PathGetDriveNumber, :PathGetDriveNumberA, [:str], :int
    attach_function :PathIsUNC, :PathIsUNCA, [:str], :bool
    attach_function :PathStripToRoot, :PathStripToRootA, [:ptr], :bool
  end
end
