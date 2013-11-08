require 'ffi'

module Windows
  module Stat
    module Functions
      extend FFI::Library

      typedef :ulong, :dword
      typedef :uintptr_t, :handle
      typedef :pointer, :ptr
      typedef :buffer_in, :buf_in
      typedef :string, :str

      ffi_convention :stdcall

      ffi_lib :kernel32

      attach_function :CloseHandle, [:handle], :bool
      attach_function :CreateFile, :CreateFileW, [:buf_in, :dword, :dword, :ptr, :dword, :dword, :handle], :handle
      attach_function :FindFirstFile, :FindFirstFileW, [:buf_in, :ptr], :handle
      attach_function :FindClose, [:handle], :bool
      attach_function :GetCurrentProcess, [], :handle
      attach_function :GetDiskFreeSpace, :GetDiskFreeSpaceW, [:buf_in, :ptr, :ptr, :ptr, :ptr], :bool
      attach_function :GetDriveType, :GetDriveTypeW, [:buf_in], :uint
      attach_function :GetFileInformationByHandle, [:handle, :ptr], :bool
      attach_function :GetFileType, [:handle], :dword
      attach_function :OpenProcessToken, [:handle, :dword, :ptr], :bool

      ffi_lib :shlwapi

      attach_function :PathGetDriveNumber, :PathGetDriveNumberW, [:buf_in], :int
      attach_function :PathIsUNC, :PathIsUNCW, [:buf_in], :bool
      attach_function :PathStripToRoot, :PathStripToRootW, [:ptr], :bool

      ffi_lib :advapi32

      attach_function :ConvertSidToStringSid, :ConvertSidToStringSidA, [:ptr, :ptr], :bool
      attach_function :GetFileSecurity, :GetFileSecurityW, [:buf_in, :int, :ptr, :dword, :ptr], :bool
      attach_function :GetSecurityDescriptorOwner, [:ptr, :ptr, :ptr], :bool
      attach_function :GetSecurityDescriptorGroup, [:ptr, :ptr, :ptr], :bool
      attach_function :GetTokenInformation, [:handle, :int, :ptr, :dword, :ptr], :bool
    end
  end
end
