# buildforkernels macro hint: when you build a new version or a new release
# that contains bugfixes or other improvements then you must disable the
# "buildforkernels newest" macro for just that build; immediately after
# queuing that build enable the macro again for subsequent builds; that way
# a new akmod package will only get build when a new one is actually needed
#
# LudOS: For bootc/rpm-ostree systems, we build kmod for specific kernel version
# The kernel version is passed via --define at build time, not via buildforkernels
# This avoids the buildsys-build-*-kerneldevpkgs dependency issue
%global debug_package %{nil}
%global _kmodtool_zipmodules 0

Name:          nvidia-tesla-kmod
Epoch:         1
# NOTE: Version is a PLACEHOLDER - overridden at build time via:
#       rpmbuild --define "version X.Y.Z" ...
#       The actual version comes from the NVIDIA driver filename
Version:       580.82.07
# Taken over by kmodtool
Release:       14.ludos%{?dist}
Summary:       NVIDIA Tesla datacenter driver kernel module
License:       Redistributable, no modification permitted
URL:           https://www.nvidia.com/

# Tesla driver source - downloaded at build time
Source0:       nvidia-tesla-driver-%{version}.tar.xz

Source11:      nvidia-kmodtool-excludekernel-filterfile
Patch0:        make_modeset_default.patch
Patch1:        ludos-tesla-optimizations.patch

Source100:     nvidia-kmod-noopen-checks
Source101:     nvidia-kmod-noopen-pciids.txt

ExclusiveArch:  x86_64

# LudOS Tesla kmod build requirements (simplified for bootc)
BuildRequires:  %{_bindir}/kmodtool
BuildRequires:  wget2-wget, curl
BuildRequires:  gcc, make
BuildRequires:  kernel-devel, kernel-headers
BuildRequires:  elfutils-libelf-devel
BuildRequires:  rpm-build

# kmodtool does its magic here
# Using --repo rpmfusion-nonfree-fedora (standard name, no metadata lookup needed with explicit kernels)
# The --for-kernels parameter from build script takes precedence over repo metadata
%{expand:%(kmodtool --target %{_target_cpu} --repo rpmfusion-nonfree-fedora --kmodname %{name} --filterfile %{SOURCE11} --obsolete-name nvidia-newest --obsolete-version "%{?epoch}:%{version}-%{release}" %{?buildforkernels:--%{buildforkernels}} %{?kernels:--for-kernels "%{?kernels}"} 2>/dev/null) }

# Common package for Tesla drivers (required by akmod)
%package common
Summary: Common files for NVIDIA Tesla drivers
Provides: nvidia-tesla-kmod-common = %{epoch}:%{version}-%{release}

%description common
Common files and configuration for NVIDIA Tesla datacenter drivers.

%files common
%defattr(-,root,root,-)
# Empty package - all files are in the kernel modules

%description
The NVIDIA Tesla %{version} datacenter driver kernel module for kernel %{kversion}.
Optimized for Tesla P4, P40, V100, and other datacenter GPUs.
Includes LudOS-specific optimizations for headless gaming and virtual display support.

%prep
# error out if there was something wrong with kmodtool
%{?kmodtool_check}

# Debug kmodtool output removed - caused issues without --repo parameter
# The package metadata is already generated correctly by the %expand macro above

%setup -T -c

# Use pre-extracted Tesla driver tarball
echo "Extracting Tesla driver tarball..."
tar -xJf %{SOURCE0}
cd nvidia-tesla-driver-%{version}

# Move kernel directory to expected location
if [ -d kernel ]; then
    mv kernel ../kernel
elif [ -d kernel-open ]; then
    mv kernel-open ../kernel
else
    echo "ERROR: No kernel directory found in Tesla driver"
    exit 1
fi

cd ..

# Switch to kernel or kernel-open
%if 0%{?_with_kmod_nvidia_open:1}
if [ -d kernel-closed ]; then
    mv kernel kernel-closed
    mv kernel-open kernel
fi
%elif 0%{!?_without_kmod_nvidia_detect:1}
echo "Runtime detection of kmod_nvidia_open"
if [ -f supported-gpus/nvidia-kmod-noopen-pciids.txt ] ; then
  bash "%{SOURCE100}" supported-gpus/nvidia-kmod-noopen-pciids.txt
else
  bash "%{SOURCE100}" "%{SOURCE101}"
fi
%endif

# patch loop
%if 0%{?_with_nvidia_defaults:1}
echo "Using original nvidia defaults"
%else
echo "Set nvidia to modeset=1 for Tesla drivers"
%patch -P0 -p1
%endif

# Apply LudOS Tesla optimizations (disabled for Tesla 580.82.07 compatibility)
%if 0%{?_with_ludos_optimizations:1}
echo "Applying LudOS Tesla optimizations"
%patch -P1 -p1
%else
echo "Skipping LudOS Tesla optimizations (disabled for driver compatibility)"
%endif

for kernel_version  in %{?kernel_versions} ; do
    cp -a kernel _kmod_build_${kernel_version%%___*}
done

%build
%if 0%{?_without_nvidia_uvm:1}
export NV_EXCLUDE_KERNEL_MODULES="${NV_EXCLUDE_KERNEL_MODULES} nvidia_uvm "
%endif
%if 0%{?_without_nvidia_modeset:1}
export NV_EXCLUDE_KERNEL_MODULES="${NV_EXCLUDE_KERNEL_MODULES} nvidia_modeset "
%endif

# Tesla-specific build flags
export NV_VERBOSE=1
export IGNORE_CC_MISMATCH=1
export IGNORE_XEN_PRESENCE=1
export IGNORE_PREEMPT_RT_PRESENCE=1

for kernel_version in %{?kernel_versions}; do
  pushd _kmod_build_${kernel_version%%___*}/
    %make_build \
        KERNEL_UNAME="${kernel_version%%___*}" SYSSRC="${kernel_version##*___}" \
        IGNORE_CC_MISMATCH=1 IGNORE_XEN_PRESENCE=1 IGNORE_PREEMPT_RT_PRESENCE=1 \
        NV_VERBOSE=1 \
        module
  popd
done

%install
# Install kernel modules
for kernel_version in %{?kernel_versions}; do
    mkdir -p  $RPM_BUILD_ROOT/%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/
    install -D -m 0755 _kmod_build_${kernel_version%%___*}/nvidia*.ko \
         $RPM_BUILD_ROOT/%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/
done

# Sign modules if MOK key is provided (for Secure Boot)
%if 0%{?mok_key:1}
echo ""
echo "========================================"
echo "=== Module Signing with MOK ==="
echo "========================================"
echo "MOK Key: %{mok_key}"
echo "MOK Cert: %{mok_crt}"
echo ""

# Verify signing prerequisites
KERNEL_VERSIONS_LIST="%{?kernel_versions}"
if [ -z "$KERNEL_VERSIONS_LIST" ]; then
  echo "❌ ERROR: kernel_versions is empty! Cannot sign modules."
  echo "This likely means kmodtool didn't generate kernel version list."
  exit 1
fi

echo "Kernel versions to sign: $KERNEL_VERSIONS_LIST"
echo ""

for kernel_version in %{?kernel_versions}; do
  KERN_VER="${kernel_version%%___*}"
  MODULE_DIR="$RPM_BUILD_ROOT/%{kmodinstdir_prefix}/${KERN_VER}/%{kmodinstdir_postfix}"
  
  echo "=== Signing modules for kernel: $KERN_VER ==="
  
  # Find sign-file
  SIGN_FILE="/usr/src/kernels/${KERN_VER}/scripts/sign-file"
  echo "Looking for sign-file at: $SIGN_FILE"
  
  if [ ! -x "$SIGN_FILE" ]; then
    echo "❌ ERROR: sign-file not found or not executable at $SIGN_FILE"
    echo "This is required for Secure Boot. Install kernel-devel package."
    exit 1
  fi
  echo "✅ Found sign-file"
  
  # Verify MOK files
  if [ ! -f "%{mok_key}" ]; then
    echo "❌ ERROR: MOK private key not found at %{mok_key}"
    exit 1
  fi
  echo "✅ Found MOK key: %{mok_key}"
  
  if [ ! -f "%{mok_crt}" ]; then
    echo "❌ ERROR: MOK certificate not found at %{mok_crt}"
    exit 1
  fi
  echo "✅ Found MOK cert: %{mok_crt}"
  
  # Sign each module
  echo "Module directory: $MODULE_DIR"
  MODULE_COUNT=0
  for ko in "$MODULE_DIR"/nvidia*.ko; do
    if [ -f "$ko" ]; then
      MODULE_COUNT=$((MODULE_COUNT + 1))
      module_name=$(basename "$ko")
      echo ""
      echo "  📝 Signing: $module_name"
      echo "     Path: $ko"
      
      if "$SIGN_FILE" sha256 "%{mok_key}" "%{mok_crt}" "$ko"; then
        echo "     ✅ Signed successfully"
        
        # Verify signature
        if modinfo "$ko" | grep -q "sig_id"; then
          echo "     ✅ Signature verified in module"
        else
          echo "     ⚠️  Warning: Could not verify signature (modinfo might not work in buildroot)"
        fi
      else
        echo "     ❌ Signing FAILED!"
        exit 1
      fi
    fi
  done
  
  if [ $MODULE_COUNT -eq 0 ]; then
    echo "❌ ERROR: No NVIDIA modules found in $MODULE_DIR"
    exit 1
  fi
  
  echo ""
  echo "✅ Successfully signed $MODULE_COUNT modules for kernel $KERN_VER"
  echo ""
done

echo "========================================"
echo "✅ All modules signed successfully!"
echo "========================================"
echo ""
%else
echo ""
echo "⚠️  WARNING: Module signing not requested (no mok_key defined)"
echo "⚠️  Modules will NOT be signed - Secure Boot will prevent loading!"
echo "⚠️  Use --define 'mok_key /path/to/key' to enable signing"
echo ""
%endif

%{?akmod_install}

%changelog
* Thu Oct  2 2025 LudOS Project <ludos@example.com> - 1:580.82.07-14.ludos
- Fix kmodtool --repo requirement (required parameter, use standard rpmfusion name)
- Remove debug kmodtool print in %prep that caused build failure
- Explicit --for-kernels from build script overrides repo metadata lookup
- Version bump per NVIDIA driver workflow policy

* Thu Oct  2 2025 LudOS Project <ludos@example.com> - 1:580.82.07-13.ludos
- Remove --repo parameter from kmodtool invocations (fixes buildsys metadata error)
- Allow kmodtool to work with explicit --for-kernels parameter only
- Version bump per NVIDIA driver workflow policy

* Thu Oct  2 2025 LudOS Project <ludos@example.com> - 1:580.82.07-12.ludos
- Fix kmodtool buildsys-build-ludos-kerneldevpkgs error
- Remove buildforkernels macro, use explicit kernel version from build script
- Proper kmod build for bootc/rpm-ostree immutable systems
- Version bump per NVIDIA driver workflow policy

* Thu Oct  2 2025 LudOS Project <ludos@example.com> - 1:580.82.07-11.ludos
- CRITICAL FIX: Change from akmod to kmod for bootc/rpm-ostree systems
- Enhanced module signing with comprehensive error checking and verification
- Fix empty kernel_versions causing unsigned modules
- Add detailed signing output for troubleshooting
- Version bump per NVIDIA driver workflow policy

* Wed Oct  1 2025 LudOS Project <ludos@example.com> - 1:580.82.07-10.ludos
- Bump Release to align with build script improvements
- Version bump per NVIDIA driver workflow policy

* Wed Oct  1 2025 LudOS Project <ludos@example.com> - 1:580.82.07-9.ludos
- Enhanced module signing with verbose logging and error checking
- Add explicit validation of sign-file, MOK key, and certificate
- Fix Secure Boot "Key was rejected by service" error
- Ensure signing actually runs during RPM build
- Version bump per NVIDIA driver workflow policy

* Wed Oct  1 2025 LudOS Project <ludos@example.com> - 1:580.82.07-8.ludos
- Bump Release to match nvidia-tesla-utils.spec for version consistency
- Align with optional GLX extension handling in utils package
- Version bump per NVIDIA driver workflow policy

* Wed Oct  1 2025 LudOS Project <ludos@example.com> - 1:580.82.07-7.ludos
- Bump Release to match nvidia-tesla-utils.spec for version consistency
- Align with complete graphics library support in utils package
- Version bump per NVIDIA driver workflow policy

* Tue Sep 30 2025 LudOS Project <ludos@example.com> - 1:580.82.07-6.ludos
- Add nouveau driver blacklisting to prevent GPU conflicts
- Configure kernel parameters to blacklist nouveau in early boot
- Add dracut configuration to omit nouveau from initramfs
- Version bump per NVIDIA driver workflow policy

* Tue Sep 30 2025 LudOS Project <ludos@example.com> - 1:580.82.07-5.ludos
- Add automatic MOK enrollment staging with mokutil --import
- Implement interactive password prompt for MOK enrollment
- Add detailed user instructions for blue MOK Manager screen
- Fix missing MOK enrollment step in Secure Boot workflow
- Version bump per NVIDIA driver workflow policy

* Tue Sep 30 2025 LudOS Project <ludos@example.com> - 1:580.82.07-4.ludos
- Fix RPM macro error: properly use %{mok_key} and %{mok_crt} macros in spec file
- Add conditional module signing only when mok_key is defined
- Improve build script to handle empty SIGN_DEFINES array correctly
- Version bump per NVIDIA driver workflow policy

* Mon Sep 29 2025 LudOS Project <ludos@example.com> - 1:580.82.07-3.ludos
- Enforce version bump for Secure Boot/MOK workflow updates and signing logic
- No functional changes beyond packaging policy alignment
* Sat Sep 28 2025 LudOS Project <ludos@example.com> - 1:580.82.07-2.ludos
- Add optional module signing in %install when built with --define 'sign_modules 1'
- Enable Secure Boot compliance when paired with MOK enrollment

* Wed Sep 18 2024 LudOS Project <ludos@example.com> - 1:580.82.07-1.ludos
- Initial Tesla datacenter driver package for LudOS
- Based on RPM Fusion nvidia-kmod with Tesla driver sources
- Optimized for headless gaming and bootc compatibility
- Added LudOS-specific optimizations for headless gaming
- Supports Tesla P4, P40, V100, and other datacenter GPUs
- Automatic Tesla driver download during build process
- Conflicts with consumer nvidia packages to prevent conflicts
