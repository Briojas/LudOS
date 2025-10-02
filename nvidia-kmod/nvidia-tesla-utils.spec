Name:           nvidia-tesla-utils
Epoch:          1
# NOTE: Version is a PLACEHOLDER - overridden at build time via:
#       rpmbuild --define "version X.Y.Z" ...
#       The actual version comes from the NVIDIA driver filename
Version:        580.82.07
Release:        14.ludos%{?dist}
Summary:        NVIDIA Tesla datacenter driver user-space utilities

License:        Redistributable, no modification permitted
URL:            https://www.nvidia.com/
Source0:        nvidia-tesla-driver-%{version}.tar.xz
Source1:        nvidia-device-setup.service

%global _missing_build_ids_terminate_build 0
%global debug_package %{nil}
%undefine _debugsource_packages

BuildArch:      x86_64
BuildRequires:  systemd-rpm-macros
Requires:       nvidia-tesla-kmod-common = %{epoch}:%{version}-%{release}
Requires(post): %{_sbindir}/ldconfig
Requires(postun): %{_sbindir}/ldconfig
Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd

%description
Complete user-space libraries and utilities from the NVIDIA Tesla %{version} datacenter driver.
Provides OpenGL, Vulkan, EGL, X.org driver, nvidia-smi, and all supporting libraries
required for graphics rendering and compute with Tesla GPUs on LudOS.

%prep
%setup -q -n nvidia-tesla-driver-%{version}

%install
rm -rf %{buildroot}

install -d %{buildroot}%{_bindir}
install -d %{buildroot}%{_libdir}
install -d %{buildroot}%{_libdir}/xorg/modules/drivers
install -d %{buildroot}%{_libdir}/xorg/modules/extensions
install -d %{buildroot}%{_libdir}/vdpau
install -d %{buildroot}%{_libdir}/gbm
install -d %{buildroot}%{_datadir}/vulkan/icd.d
install -d %{buildroot}%{_datadir}/vulkan/implicit_layer.d
install -d %{buildroot}%{_datadir}/glvnd/egl_vendor.d
install -d %{buildroot}%{_datadir}/egl/egl_external_platform.d
install -d %{buildroot}%{_datadir}/doc/%{name}
install -d %{buildroot}%{_datadir}/licenses/%{name}
install -d %{buildroot}%{_sysconfdir}/nvidia
install -d %{buildroot}%{_sysconfdir}/OpenCL/vendors
install -d %{buildroot}%{_unitdir}

# Binaries (Tesla .run places these at top-level rather than usr/bin)
if [ -f nvidia-smi ]; then
    install -m 0755 nvidia-smi %{buildroot}%{_bindir}/
elif [ -f usr/bin/nvidia-smi ]; then
    install -m 0755 usr/bin/nvidia-smi %{buildroot}%{_bindir}/
else
    echo "nvidia-smi binary not found in Tesla driver payload" >&2
    exit 1
fi

if [ -f nvidia-debugdump ]; then
    install -m 0755 nvidia-debugdump %{buildroot}%{_bindir}/
elif [ -f usr/bin/nvidia-debugdump ]; then
    install -m 0755 usr/bin/nvidia-debugdump %{buildroot}%{_bindir}/
fi
if [ -f nvidia-bug-report.sh ]; then
    install -m 0755 nvidia-bug-report.sh %{buildroot}%{_bindir}/
elif [ -f usr/bin/nvidia-bug-report.sh ]; then
    install -m 0755 usr/bin/nvidia-bug-report.sh %{buildroot}%{_bindir}/
fi

# nvidia-modprobe (for creating device nodes and loading UVM)
if [ -f nvidia-modprobe ]; then
    install -m 0755 nvidia-modprobe %{buildroot}%{_bindir}/
elif [ -f usr/bin/nvidia-modprobe ]; then
    install -m 0755 usr/bin/nvidia-modprobe %{buildroot}%{_bindir}/
fi

# Install systemd service to create device nodes at boot
install -m 0644 %{SOURCE1} %{buildroot}%{_unitdir}/nvidia-device-setup.service

# Function to find and install libraries from various possible locations
install_lib() {
    local lib=$1
    local found=0
    for dir in . lib lib64 usr/lib usr/lib64; do
        if compgen -G "${dir}/${lib}*" >/dev/null 2>&1; then
            cp -a ${dir}/${lib}* %{buildroot}%{_libdir}/
            found=1
            break
        fi
    done
    if [ $found -eq 0 ]; then
        echo "Warning: Library $lib not found" >&2
    fi
}

# Core NVIDIA libraries
for lib in \
    libnvidia-ml.so \
    libnvidia-cfg.so \
    libnvidia-glcore.so \
    libnvidia-tls.so \
    libnvidia-glsi.so \
    libnvidia-rtcore.so \
    libnvidia-cbl.so \
    libnvidia-eglcore.so \
    libnvidia-glvkspirv.so \
    libnvidia-allocator.so \
    libnvidia-vulkan-producer.so \
    libnvidia-fbc.so \
    libnvidia-encode.so \
    libnvidia-opticalflow.so \
    libnvidia-ngx.so \
    libnvidia-nvvm.so \
    libnvidia-ptxjitcompiler.so \
    libnvidia-gpucomp.so; do
    install_lib "$lib"
done

# OpenGL libraries
for lib in \
    libGLX_nvidia.so \
    libEGL_nvidia.so \
    libGLESv1_CM_nvidia.so \
    libGLESv2_nvidia.so; do
    install_lib "$lib"
done

# CUDA libraries
for lib in \
    libcuda.so \
    libnvcuvid.so \
    libnvidia-compiler.so; do
    install_lib "$lib"
done

# OpenCL library
install_lib "libnvidia-opencl.so"

# VDPAU driver
if compgen -G "**/libvdpau_nvidia.so*" >/dev/null 2>&1; then
    find . -name "libvdpau_nvidia.so*" -exec cp -a {} %{buildroot}%{_libdir}/vdpau/ \;
fi

# GBM backend
install_lib "libnvidia-egl-gbm.so"

# X.org driver
if [ -f nvidia_drv.so ]; then
    install -m 0755 nvidia_drv.so %{buildroot}%{_libdir}/xorg/modules/drivers/
elif [ -f usr/lib/xorg/modules/drivers/nvidia_drv.so ]; then
    install -m 0755 usr/lib/xorg/modules/drivers/nvidia_drv.so %{buildroot}%{_libdir}/xorg/modules/drivers/
elif [ -f usr/lib64/xorg/modules/drivers/nvidia_drv.so ]; then
    install -m 0755 usr/lib64/xorg/modules/drivers/nvidia_drv.so %{buildroot}%{_libdir}/xorg/modules/drivers/
fi

# GLX extension for X.org (optional - not present in all Tesla drivers)
if [ -f libglxserver_nvidia.so ]; then
    install -m 0755 libglxserver_nvidia.so.%{version} %{buildroot}%{_libdir}/xorg/modules/extensions/ 2>/dev/null || \
    install -m 0755 libglxserver_nvidia.so %{buildroot}%{_libdir}/xorg/modules/extensions/ 2>/dev/null || true
    echo "GLX extension found and installed"
elif [ -f usr/lib64/xorg/modules/extensions/libglxserver_nvidia.so.%{version} ]; then
    install -m 0755 usr/lib64/xorg/modules/extensions/libglxserver_nvidia.so.%{version} %{buildroot}%{_libdir}/xorg/modules/extensions/
    echo "GLX extension found and installed"
else
    echo "Note: GLX extension not found (normal for datacenter drivers)"
fi

# Vulkan ICD
if [ -f nvidia_icd.json ]; then
    install -m 0644 nvidia_icd.json %{buildroot}%{_datadir}/vulkan/icd.d/
elif [ -f usr/share/vulkan/icd.d/nvidia_icd.json ]; then
    install -m 0644 usr/share/vulkan/icd.d/nvidia_icd.json %{buildroot}%{_datadir}/vulkan/icd.d/
fi

# Vulkan layers
if [ -f nvidia_layers.json ]; then
    install -m 0644 nvidia_layers.json %{buildroot}%{_datadir}/vulkan/implicit_layer.d/
elif [ -f usr/share/vulkan/implicit_layer.d/nvidia_layers.json ]; then
    install -m 0644 usr/share/vulkan/implicit_layer.d/nvidia_layers.json %{buildroot}%{_datadir}/vulkan/implicit_layer.d/
fi

# EGL vendor files
if [ -f 10_nvidia.json ]; then
    install -m 0644 10_nvidia.json %{buildroot}%{_datadir}/glvnd/egl_vendor.d/
elif [ -f usr/share/glvnd/egl_vendor.d/10_nvidia.json ]; then
    install -m 0644 usr/share/glvnd/egl_vendor.d/10_nvidia.json %{buildroot}%{_datadir}/glvnd/egl_vendor.d/
fi

# EGL external platform
if [ -f 10_nvidia_wayland.json ]; then
    install -m 0644 10_nvidia_wayland.json %{buildroot}%{_datadir}/egl/egl_external_platform.d/
elif [ -f usr/share/egl/egl_external_platform.d/10_nvidia_wayland.json ]; then
    install -m 0644 usr/share/egl/egl_external_platform.d/10_nvidia_wayland.json %{buildroot}%{_datadir}/egl/egl_external_platform.d/
fi

# OpenCL vendor file
if [ -f nvidia.icd ]; then
    install -m 0644 nvidia.icd %{buildroot}%{_sysconfdir}/OpenCL/vendors/
elif [ -f etc/OpenCL/vendors/nvidia.icd ]; then
    install -m 0644 etc/OpenCL/vendors/nvidia.icd %{buildroot}%{_sysconfdir}/OpenCL/vendors/
fi

# Documentation / licenses
if [ -f LICENSE ]; then
    install -m 0644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/
fi
for doc in README* NVIDIA_Changelog supported-gpus.json; do
    if [ -f "$doc" ]; then
        install -m 0644 "$doc" %{buildroot}%{_datadir}/doc/%{name}/
    fi
done

%post
%{_sbindir}/ldconfig
%systemd_post nvidia-device-setup.service

%preun
%systemd_preun nvidia-device-setup.service

%postun
%{_sbindir}/ldconfig
%systemd_postun_with_restart nvidia-device-setup.service

%files
%license %{_datadir}/licenses/%{name}/*
%doc %{_datadir}/doc/%{name}/*

# Binaries
%{_bindir}/nvidia-smi
%{_bindir}/nvidia-debugdump
%{_bindir}/nvidia-bug-report.sh
%{_bindir}/nvidia-modprobe

# Core NVIDIA libraries
%{_libdir}/libnvidia-*.so*
%{_libdir}/libcuda.so*
%{_libdir}/libnvcuvid.so*

# OpenGL libraries
%{_libdir}/libGLX_nvidia.so*
%{_libdir}/libEGL_nvidia.so*
%{_libdir}/libGLESv1_CM_nvidia.so*
%{_libdir}/libGLESv2_nvidia.so*

# VDPAU
%{_libdir}/vdpau/libvdpau_nvidia.so*

# X.org driver (GLX extension may not be present in datacenter drivers)
%{_libdir}/xorg/modules/drivers/nvidia_drv.so

# Vulkan
%{_datadir}/vulkan/icd.d/nvidia_icd.json
%{_datadir}/vulkan/implicit_layer.d/nvidia_layers.json

# EGL
%{_datadir}/glvnd/egl_vendor.d/10_nvidia.json
%{_datadir}/egl/egl_external_platform.d/10_nvidia_wayland.json

# GBM
%{_libdir}/libnvidia-egl-gbm.so*
%{_libdir}/gbm/

# OpenCL
%{_sysconfdir}/OpenCL/vendors/nvidia.icd

# Systemd
%{_unitdir}/nvidia-device-setup.service

%changelog
* Thu Oct  2 2025 LudOS Project <ludos@example.com> - 1:580.82.07-14.ludos
- Bump Release to match nvidia-tesla-kmod.spec (kmodtool --repo requirement fix)
- Version bump per NVIDIA driver workflow policy

* Thu Oct  2 2025 LudOS Project <ludos@example.com> - 1:580.82.07-13.ludos
- Bump Release to match nvidia-tesla-kmod.spec (kmodtool --repo fix)
- Version bump per NVIDIA driver workflow policy

* Thu Oct  2 2025 LudOS Project <ludos@example.com> - 1:580.82.07-12.ludos
- Bump Release to match nvidia-tesla-kmod.spec (kmodtool fix release)
- Align with explicit kernel version build approach
- Version bump per NVIDIA driver workflow policy

* Thu Oct  2 2025 LudOS Project <ludos@example.com> - 1:580.82.07-11.ludos
- Bump Release to match nvidia-tesla-kmod.spec (kmod fix release)
- Align with akmod→kmod transition for bootc/rpm-ostree compatibility
- Version bump per NVIDIA driver workflow policy

* Wed Oct  1 2025 LudOS Project <ludos@example.com> - 1:580.82.07-10.ludos
- Bump Release to match nvidia-tesla-kmod.spec for version consistency
- Version bump per NVIDIA driver workflow policy

* Wed Oct  1 2025 LudOS Project <ludos@example.com> - 1:580.82.07-9.ludos
- Bump Release to match nvidia-tesla-kmod.spec for version consistency
- Align with module signing enhancements
- Version bump per NVIDIA driver workflow policy

* Wed Oct  1 2025 LudOS Project <ludos@example.com> - 1:580.82.07-8.ludos
- Make GLX extension optional (not present in datacenter Tesla drivers)
- Fix RPM build failure when libglxserver_nvidia.so doesn't exist
- Gracefully handle missing optional libraries
- Version bump per NVIDIA driver workflow policy

* Wed Oct  1 2025 LudOS Project <ludos@example.com> - 1:580.82.07-7.ludos
- Add complete graphics library support (OpenGL, Vulkan, EGL, X.org)
- Package all required libraries for hardware-accelerated rendering
- Include Vulkan ICD for GPU compute and graphics
- Add VDPAU, GBM, and OpenCL support
- Enable Gamescope and Sunshine hardware encoding with NVIDIA
- Version bump per NVIDIA driver workflow policy

* Tue Sep 30 2025 LudOS Project <ludos@example.com> - 1:580.82.07-6.ludos
- Bump Release to match nvidia-tesla-kmod.spec for version consistency
- Align with nouveau blacklisting improvements
- Version bump per NVIDIA driver workflow policy

* Tue Sep 30 2025 LudOS Project <ludos@example.com> - 1:580.82.07-5.ludos
- Bump Release to match nvidia-tesla-kmod.spec for version consistency
- Align with MOK enrollment workflow improvements
- Version bump per NVIDIA driver workflow policy

* Tue Sep 30 2025 LudOS Project <ludos@example.com> - 1:580.82.07-4.ludos
- Bump Release to match nvidia-tesla-kmod.spec for version consistency
- Fix dependency resolution error between kmod-common and utils packages
- Version bump per NVIDIA driver workflow policy

* Tue Sep 30 2025 LudOS Project <ludos@example.com> - 1:580.82.07-3.ludos
- Skipped for version alignment

* Sat Sep 28 2025 LudOS Project <ludos@example.com> - 1:580.82.07-2.ludos
- Add nvidia-modprobe and systemd unit to create /dev/nvidia* at boot
- Integrate systemd macros and dependencies
- Prepare utils package for Secure Boot workflows
* Fri Sep 26 2025 LudOS Project <ludos@example.com> - 1:580.82.07-1.ludos
- Initial packaging of NVIDIA Tesla user-space utilities for LudOS
- Provides nvidia-smi and NVML libraries alongside Tesla kmod packages
