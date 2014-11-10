require_relative 'constants'

require 'ffi'

module Windows
  module Stat
    module Structs
      extend FFI::Library

      private

      class LowHighLarge < FFI::Struct
        layout(:LowPart, :ulong, :HighPart, :long)
      end

      class LARGE_INTEGER < FFI::Union
        layout(:u, LowHighLarge, :QuadPart, :ulong_long)
      end

      class FILE_STREAM_INFORMATION < FFI::Struct
        layout(
          :NextEntryOffset, :ulong,
          :StreamNameLength, :ulong,
          :StreamSize, LARGE_INTEGER,
          :StreamAllocateSize, LARGE_INTEGER,
          :StreamName, :pointer
        )
      end

      class IO_STATUS_BLOCK < FFI::Struct
        layout(
          :union, Class.new(FFI::Union){ layout(:Status, :long, :Pointer, :pointer) },
          :Information, :uintptr_t
        )
      end

      class LowHigh < FFI::Struct
        layout(:LowPart, :ulong, :HighPart, :ulong)
      end

      class ULARGE_INTEGER < FFI::Union
        layout(:u, LowHigh, :QuadPart, :ulong_long)
      end

      class FILETIME < FFI::Struct
        layout(:dwLowDateTime, :ulong, :dwHighDateTime, :ulong)
      end

      class BY_HANDLE_FILE_INFORMATION < FFI::Struct
        include Windows::Stat::Constants

        layout(
          :dwFileAttributes, :ulong,
          :ftCreationTime, FILETIME,
          :ftLastAccessTime, FILETIME,
          :ftLastWriteTime, FILETIME,
          :dwVolumeSerialNumber, :ulong,
          :nFileSizeHigh, :ulong,
          :nFileSizeLow, :ulong,
          :nNumberOfLinks, :ulong,
          :nFileIndexHigh, :ulong,
          :nFileIndexLow, :ulong
        )

        # Return the atime as a number
        def atime
          date = ULARGE_INTEGER.new
          date[:u][:LowPart] = self[:ftLastAccessTime][:dwLowDateTime]
          date[:u][:HighPart] = self[:ftLastAccessTime][:dwHighDateTime]
          date[:QuadPart] / 10000000 - 11644473600 # ns, 100-ns since Jan 1, 1601.
        end

        # Return the ctime as a number
        def ctime
          date = ULARGE_INTEGER.new
          date[:u][:LowPart] = self[:ftCreationTime][:dwLowDateTime]
          date[:u][:HighPart] = self[:ftCreationTime][:dwHighDateTime]
          date[:QuadPart] / 10000000 - 11644473600 # ns, 100-ns since Jan 1, 1601.
        end

        # Return the mtime as a number
        def mtime
          date = ULARGE_INTEGER.new
          date[:u][:LowPart] = self[:ftLastWriteTime][:dwLowDateTime]
          date[:u][:HighPart] = self[:ftLastWriteTime][:dwHighDateTime]
          date[:QuadPart] / 10000000 - 11644473600 # ns, 100-ns since Jan 1, 1601.
        end

        # Return the size as a single number
        def size
          (self[:nFileSizeHigh] * (MAXDWORD + 1)) + self[:nFileSizeLow]
        end
      end

      class WIN32_FIND_DATA < FFI::Struct
        include Windows::Stat::Constants

        layout(
          :dwFileAttributes, :ulong,
          :ftCreationTime, FILETIME,
          :ftLastAccessTime, FILETIME,
          :ftLastWriteTime, FILETIME,
          :nFileSizeHigh, :ulong,
          :nFileSizeLow, :ulong,
          :dwReserved0, :ulong,
          :dwReserved1, :ulong,
          :cFileName, [:uint8, MAX_PATH*2],
          :cAlternateFileName, [:uint8, 28]
        )

        # Return the atime as a number
        def atime
          date = ULARGE_INTEGER.new
          date[:u][:LowPart] = self[:ftLastAccessTime][:dwLowDateTime]
          date[:u][:HighPart] = self[:ftLastAccessTime][:dwHighDateTime]
          return 0 if date[:QuadPart]==0
          date[:QuadPart] / 10000000 - 11644473600 # ns, 100-ns since Jan 1, 1601.
        end

        # Return the ctime as a number
        def ctime
          date = ULARGE_INTEGER.new
          date[:u][:LowPart] = self[:ftCreationTime][:dwLowDateTime]
          date[:u][:HighPart] = self[:ftCreationTime][:dwHighDateTime]
          return 0 if date[:QuadPart]==0
          date[:QuadPart] / 10000000 - 11644473600 # ns, 100-ns since Jan 1, 1601.
        end

        # Return the mtime as a number
        def mtime
          date = ULARGE_INTEGER.new
          date[:u][:LowPart] = self[:ftLastWriteTime][:dwLowDateTime]
          date[:u][:HighPart] = self[:ftLastWriteTime][:dwHighDateTime]
          return 0 if date[:QuadPart]==0
          date[:QuadPart] / 10000000 - 11644473600 # ns, 100-ns since Jan 1, 1601.
        end

        # Return the size as a single number
        def size
          (self[:nFileSizeHigh] * (MAXDWORD + 1)) + self[:nFileSizeLow]
        end
      end

      class SID_AND_ATTRIBUTES < FFI::Struct
        layout(:Sid, :pointer, :Attributes, :ulong)
      end

      class TOKEN_GROUP < FFI::Struct
        layout(
          :GroupCount, :ulong,
          :Groups, [SID_AND_ATTRIBUTES, 128]
        )
      end

      class GENERIC_MAPPING < FFI::Struct
        layout(
          :GenericRead, :ulong,
          :GenericWrite, :ulong,
          :GenericExecute, :ulong,
          :GenericAll, :ulong
        )
      end

      class LUID_AND_ATTRIBUTES < FFI::Struct
        layout(
          :Luid, LowHigh,
          :Attributes, :ulong
        )
      end

      class PRIVILEGE_SET < FFI::Struct
        layout(
          :PrivilegeCount, :ulong,
          :Control, :ulong,
          :Privilege, [LUID_AND_ATTRIBUTES, 1]
        )
      end

      class TRUSTEE < FFI::Struct
        layout(
          :pMultipleTrustee, :pointer,
          :MultipleTrusteeOperation, :ulong,
          :TrusteeForm, :ulong,
          :TrusteeType, :ulong,
          :ptstrName, :pointer
        )
      end
    end
  end
end
