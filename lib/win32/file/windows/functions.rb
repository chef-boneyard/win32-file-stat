require 'ffi'

module Windows
  module Stat
    module Functions
      extend FFI::Library

      # Wrapper method for attach_pfunc + private
      def self.attach_pfunc(*args)
        attach_function(*args)
        private args[0]
      end

      typedef :ulong, :dword
      typedef :uintptr_t, :handle
      typedef :pointer, :ptr
      typedef :buffer_in, :buf_in
      typedef :string, :str

      ffi_convention :stdcall

      ffi_lib :kernel32

      attach_pfunc :CloseHandle, [:handle], :bool
      attach_pfunc :CreateFile, :CreateFileW, [:buf_in, :dword, :dword, :ptr, :dword, :dword, :handle], :handle
      attach_pfunc :FindFirstFile, :FindFirstFileW, [:buf_in, :ptr], :handle
      attach_pfunc :FindClose, [:handle], :bool
      attach_pfunc :GetCurrentProcess, [], :handle
      attach_pfunc :GetDiskFreeSpace, :GetDiskFreeSpaceW, [:buf_in, :ptr, :ptr, :ptr, :ptr], :bool
      attach_pfunc :GetDriveType, :GetDriveTypeW, [:buf_in], :uint
      attach_pfunc :GetFileInformationByHandle, [:handle, :ptr], :bool
      attach_pfunc :GetFileType, [:handle], :dword
      attach_pfunc :OpenProcessToken, [:handle, :dword, :ptr], :bool

      ffi_lib :shlwapi

      attach_pfunc :PathGetDriveNumber, :PathGetDriveNumberW, [:buf_in], :int
      attach_pfunc :PathIsUNC, :PathIsUNCW, [:buf_in], :bool
      attach_pfunc :PathStripToRoot, :PathStripToRootW, [:ptr], :bool

      ffi_lib :advapi32

      attach_pfunc :ConvertSidToStringSid, :ConvertSidToStringSidA, [:ptr, :ptr], :bool
      attach_pfunc :GetFileSecurity, :GetFileSecurityW, [:buf_in, :int, :ptr, :dword, :ptr], :bool
      attach_pfunc :GetSecurityDescriptorOwner, [:ptr, :ptr, :ptr], :bool
      attach_pfunc :GetSecurityDescriptorGroup, [:ptr, :ptr, :ptr], :bool
      attach_pfunc :GetTokenInformation, [:handle, :int, :ptr, :dword, :ptr], :bool
    end
  end
end
