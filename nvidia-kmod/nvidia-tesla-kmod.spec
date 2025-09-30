# buildforkernels macro hint: when you build a new version or a new release
# that contains bugfixes or other improvements then you must disable the
# "buildforkernels newest" macro for just that build; immediately after
# queuing that build enable the macro again for subsequent builds; that way
# a new akmod package will only get build when a new one is actually needed
%if 0%{?fedora}
%global buildforkernels akmod
%endif
%global debug_package %{nil}
%global _kmodtool_zipmodules 0

Name:          nvidia-tesla-kmod
Epoch:         1
Version:       580.82.07
# Taken over by kmodtool
Release:       5.ludos%{?dist}
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
%{expand:%(kmodtool --target %{_target_cpu} --repo ludos --kmodname %{name} --filterfile %{SOURCE11} --obsolete-name nvidia-newest --obsolete-version "%{?epoch}:%{version}-%{release}" %{?buildforkernels:--%{buildforkernels}} %{?kernels:--for-kernels "%{?kernels}"} 2>/dev/null) }

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

# print kmodtool output for debugging purposes:
kmodtool  --target %{_target_cpu}  --repo ludos --kmodname %{name} --filterfile %{SOURCE11} --obsolete-name nvidia-newest --obsolete-version "%{?epoch}:%{version}-%{release}" %{?buildforkernels:--%{buildforkernels}} %{?kernels:--for-kernels "%{?kernels}"} 2>/dev/null

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
for kernel_version in %{?kernel_versions}; do
    mkdir -p  $RPM_BUILD_ROOT/%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/
    install -D -m 0755 _kmod_build_${kernel_version%%___*}/nvidia*.ko \
         $RPM_BUILD_ROOT/%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/
done
%if 0%{?mok_key:1}
echo "Attempting to sign NVIDIA kernel modules with MOK"
for kernel_version in %{?kernel_versions}; do
  sign="/usr/src/kernels/${kernel_version%%___*}/scripts/sign-file"
  if [ -x "$sign" ] && [ -f "%{mok_key}" ] && [ -f "%{mok_crt}" ]; then
    for ko in $RPM_BUILD_ROOT/%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/nvidia*.ko; do
      "$sign" sha256 %{mok_key} %{mok_crt} "$ko" || exit 1
    done
    echo "Successfully signed modules with MOK"
  else
    echo "WARNING: sign-file or MOK files not found, skipping signing"
    exit 1
  fi
done
%else
echo "Module signing not requested (no mok_key defined)"
%endif
%{?akmod_install}

%changelog
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
