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
Release:       1.ludos%{?dist}
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

# get the needed BuildRequires (in parts depending on what we build for)
%global AkmodsBuildRequires %{_bindir}/kmodtool, nvidia-tesla-kmodsrc = %{epoch}:%{version}
BuildRequires:  %{AkmodsBuildRequires}
BuildRequires:  wget, curl

%{!?kernels:BuildRequires: gcc, elfutils-libelf-devel, buildsys-build-rpmfusion-kerneldevpkgs-%{?buildforkernels:%{buildforkernels}}%{!?buildforkernels:current}-%{_target_cpu} }

# kmodtool does its magic here
%{expand:%(kmodtool --target %{_target_cpu} --repo ludos --kmodname %{name} --filterfile %{SOURCE11} --obsolete-name nvidia-newest --obsolete-version "%{?epoch}:%{version}-%{release}" %{?buildforkernels:--%{buildforkernels}} %{?kernels:--for-kernels "%{?kernels}"} 2>/dev/null) }

# Tesla-specific provides/requires
Provides:      nvidia-tesla-kmod = %{epoch}:%{version}-%{release}
Provides:      nvidia-kmod = %{epoch}:%{version}-%{release}
Conflicts:     kmod-nvidia, akmod-nvidia

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

# Download Tesla driver if not already present
if [ ! -f "%{SOURCE0}" ]; then
    echo "Downloading Tesla driver %{version}..."
    TESLA_URL="http://us.download.nvidia.com/tesla/%{version}/NVIDIA-Linux-x86_64-%{version}.run"
    
    # Download Tesla driver
    wget -O "NVIDIA-Linux-x86_64-%{version}.run" "$TESLA_URL" || \
    curl -o "NVIDIA-Linux-x86_64-%{version}.run" "$TESLA_URL" || {
        echo "ERROR: Failed to download Tesla driver from $TESLA_URL"
        echo "Please manually download and place in SOURCES/ directory"
        exit 1
    }
    
    # Extract Tesla driver
    echo "Extracting Tesla driver..."
    mkdir nvidia-tesla-driver-%{version}
    sh "NVIDIA-Linux-x86_64-%{version}.run" --extract-only --target nvidia-tesla-driver-%{version}/
    
    # Create tarball
    tar -cJf "%{SOURCE0}" nvidia-tesla-driver-%{version}/
fi

# Extract from tarball
tar --use-compress-program xz -xf %{SOURCE0}
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

# Apply LudOS Tesla optimizations
%if 0%{?_without_ludos_optimizations:1}
echo "Skipping LudOS Tesla optimizations"
%else
echo "Applying LudOS Tesla optimizations"
%patch -P1 -p1 || echo "LudOS optimization patch not found, continuing..."
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
%{?akmod_install}

%changelog
* Wed Sep 18 2025 LudOS Project <ludos@example.com> - 1:580.82.07-1.ludos
- Initial Tesla datacenter driver package for LudOS
- Based on RPM Fusion nvidia-kmod with Tesla driver sources
- Added LudOS-specific optimizations for headless gaming
- Supports Tesla P4, P40, V100, and other datacenter GPUs
- Automatic Tesla driver download during build process
- Conflicts with consumer nvidia packages to prevent conflicts
