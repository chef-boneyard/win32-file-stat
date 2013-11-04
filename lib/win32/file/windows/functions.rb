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
    attach_function :CreateFile, :CreateFileW, [:buf_in, :dword, :dword, :ptr, :dword, :dword, :handle], :handle
    attach_function :FindFirstFile, :FindFirstFileA, [:str, :ptr], :handle
    attach_function :FindClose, [:handle], :bool

    attach_function :GetDiskFreeSpace, :GetDiskFreeSpaceW, [:buf_in, :ptr, :ptr, :ptr, :ptr], :bool
    attach_function :GetDriveType, :GetDriveTypeW, [:buf_in], :uint
    attach_function :GetFileInformationByHandle, [:handle, :ptr], :bool
    attach_function :GetFileType, [:handle], :dword

    ffi_lib :shlwapi

    attach_function :PathGetDriveNumber, :PathGetDriveNumberW, [:buf_in], :int
    attach_function :PathIsUNC, :PathIsUNCW, [:buf_in], :bool
    attach_function :PathStripToRoot, :PathStripToRootW, [:ptr], :bool
  end
end
