# LudOS Tesla NVIDIA kmod spec - Simplified for bootc/rpm-ostree
# Bypasses kmodtool's automatic package generation to avoid metadata dependencies
# Kernel version is passed explicitly via --define at build time

%global debug_package %{nil}

# These must be defined at build time via --define
%{!?kernel_version: %{error: kernel_version must be defined via --define}}

Name:          kmod-nvidia-tesla
Epoch:         1
# NOTE: Version is a PLACEHOLDER - overridden at build time via:
#       rpmbuild --define "version X.Y.Z" ...
#       The actual version comes from the NVIDIA driver filename
Version:       580.82.07
Release:       1.ludos%{?dist}
Summary:       NVIDIA Tesla datacenter driver kernel module for kernel %{kernel_version}
License:       Redistributable, no modification permitted
URL:           https://www.nvidia.com/

# Tesla driver source
Source0:       nvidia-tesla-driver-%{version}.tar.xz
Patch0:        make_modeset_default.patch
Patch1:        ludos-tesla-optimizations.patch

Source100:     nvidia-kmod-noopen-checks
Source101:     nvidia-kmod-noopen-pciids.txt

ExclusiveArch:  x86_64

BuildRequires:  gcc, make
BuildRequires:  kernel-devel = %{kernel_version}
BuildRequires:  kernel-headers
BuildRequires:  elfutils-libelf-devel

Requires:       nvidia-tesla-kmod-common = %{epoch}:%{version}-%{release}
Requires:       kernel = %{kernel_version}

Provides:       kmod-nvidia-tesla-%{kernel_version} = %{epoch}:%{version}-%{release}

%description
NVIDIA Tesla %{version} datacenter driver kernel modules for kernel %{kernel_version}.
Optimized for Tesla P4, P40, V100, and other datacenter GPUs.
Built for bootc/rpm-ostree immutable systems.

# Common package
%package -n nvidia-tesla-kmod-common
Summary: Common files for NVIDIA Tesla drivers
Provides: nvidia-tesla-kmod-common = %{epoch}:%{version}-%{release}

%description -n nvidia-tesla-kmod-common
Common files and configuration for NVIDIA Tesla datacenter drivers.

%files -n nvidia-tesla-kmod-common
%defattr(-,root,root,-)
# Placeholder - actual files in kernel module package

%prep
%setup -q -c -T

# Extract Tesla driver tarball
echo "Extracting Tesla driver tarball..."
tar -xJf %{SOURCE0}
cd nvidia-tesla-driver-%{version}

# Move kernel directory
if [ -d kernel ]; then
    mv kernel ../kernel
elif [ -d kernel-open ]; then
    mv kernel-open ../kernel
else
    echo "ERROR: No kernel directory found"
    exit 1
fi
cd ..

# Runtime detection of open vs closed kernel
%if 0%{!?_without_kmod_nvidia_detect:1}
echo "Runtime detection of kmod_nvidia_open"
if [ -f nvidia-tesla-driver-%{version}/supported-gpus/nvidia-kmod-noopen-pciids.txt ]; then
  bash "%{SOURCE100}" nvidia-tesla-driver-%{version}/supported-gpus/nvidia-kmod-noopen-pciids.txt
else
  bash "%{SOURCE100}" "%{SOURCE101}"
fi
%endif

# Apply patches
cd kernel
%if 0%{!?_with_nvidia_defaults:1}
echo "Applying modeset=1 patch for Tesla drivers"
%patch -P0 -p2
%endif

# LudOS optimizations disabled for compatibility
%if 0%{?_with_ludos_optimizations:1}
echo "Applying LudOS Tesla optimizations"
%patch -P1 -p2
%else
echo "Skipping LudOS optimizations (disabled for compatibility)"
%endif
cd ..

%build
cd kernel

# Tesla-specific build flags
export NV_VERBOSE=1
export IGNORE_CC_MISMATCH=1
export IGNORE_XEN_PRESENCE=1
export IGNORE_PREEMPT_RT_PRESENCE=1

# Build modules
%make_build \
    KERNEL_UNAME="%{kernel_version}" \
    SYSSRC="/usr/src/kernels/%{kernel_version}" \
    IGNORE_CC_MISMATCH=1 \
    IGNORE_XEN_PRESENCE=1 \
    IGNORE_PREEMPT_RT_PRESENCE=1 \
    NV_VERBOSE=1 \
    module

%install
mkdir -p %{buildroot}/usr/lib/modules/%{kernel_version}/extra/nvidia-tesla/
install -D -m 0755 kernel/nvidia*.ko %{buildroot}/usr/lib/modules/%{kernel_version}/extra/nvidia-tesla/

# Sign modules if MOK key provided (for Secure Boot)
%if 0%{?mok_key:1}
echo ""
echo "========================================"
echo "=== Module Signing with MOK ==="
echo "========================================"
echo "MOK Key: %{mok_key}"
echo "MOK Cert: %{mok_crt}"
echo ""

SIGN_FILE="/usr/src/kernels/%{kernel_version}/scripts/sign-file"
echo "sign-file path: $SIGN_FILE"

if [ ! -x "$SIGN_FILE" ]; then
  echo "❌ ERROR: sign-file not found at $SIGN_FILE"
  exit 1
fi
echo "✅ Found sign-file"

if [ ! -f "%{mok_key}" ] || [ ! -f "%{mok_crt}" ]; then
  echo "❌ ERROR: MOK key/cert not found"
  exit 1
fi
echo "✅ Found MOK key and cert"

echo ""
echo "Signing NVIDIA Tesla modules..."
MODULE_COUNT=0
for ko in %{buildroot}/usr/lib/modules/%{kernel_version}/extra/nvidia-tesla/nvidia*.ko; do
  if [ -f "$ko" ]; then
    MODULE_COUNT=$((MODULE_COUNT + 1))
    module_name=$(basename "$ko")
    echo "  📝 Signing: $module_name"
    
    if "$SIGN_FILE" sha256 "%{mok_key}" "%{mok_crt}" "$ko"; then
      echo "     ✅ Signed successfully"
    else
      echo "     ❌ Signing FAILED"
      exit 1
    fi
  fi
done

if [ $MODULE_COUNT -eq 0 ]; then
  echo "❌ ERROR: No modules found to sign"
  exit 1
fi

echo ""
echo "✅ Successfully signed $MODULE_COUNT modules"
echo "========================================"
echo ""
%else
echo ""
echo "⚠️  WARNING: Module signing not requested (no mok_key defined)"
echo "⚠️  Modules will NOT be signed - Secure Boot will prevent loading"
echo ""
%endif

%files
%defattr(-,root,root,-)
/usr/lib/modules/%{kernel_version}/extra/nvidia-tesla/

%changelog
* Thu Oct  2 2025 LudOS Project <ludos@example.com> - 1:580.82.07-1.ludos
- Complete rewrite: Manual kmod package definition (no kmodtool dependency)
- Bypasses kmodtool metadata lookup issues
- Direct kernel module build for bootc/rpm-ostree systems
- Explicit kernel version via --define at build time
- Proper module signing support with MOK
