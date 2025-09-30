Name:           nvidia-tesla-utils
Epoch:          1
Version:        580.82.07
Release:        5.ludos%{?dist}
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
User-space utilities and libraries from the NVIDIA Tesla %{version} datacenter driver.
Provides the `nvidia-smi` tool and supporting NVML libraries required to
interact with Tesla GPUs on LudOS.

%prep
%setup -q -n nvidia-tesla-driver-%{version}

%install
rm -rf %{buildroot}

install -d %{buildroot}%{_bindir}
install -d %{buildroot}%{_libdir}
install -d %{buildroot}%{_datadir}/doc/%{name}
install -d %{buildroot}%{_datadir}/licenses/%{name}
install -d %{buildroot}%{_sysconfdir}/nvidia
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

# Libraries required by nvidia-smi
for lib in libnvidia-ml.so libnvidia-cfg.so; do
    if compgen -G "${lib}*" >/dev/null; then
        cp -a ${lib}* %{buildroot}%{_libdir}/
    elif compgen -G "lib/${lib}*" >/dev/null; then
        cp -a lib/${lib}* %{buildroot}%{_libdir}/
    elif compgen -G "lib64/${lib}*" >/dev/null; then
        cp -a lib64/${lib}* %{buildroot}%{_libdir}/
    elif compgen -G "usr/lib64/${lib}*" >/dev/null; then
        cp -a usr/lib64/${lib}* %{buildroot}%{_libdir}/
    fi
done

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
%{_bindir}/nvidia-smi
%{_libdir}/libnvidia-ml.so*
%{_libdir}/libnvidia-cfg.so*
%{_bindir}/nvidia-debugdump
%{_bindir}/nvidia-bug-report.sh
%{_bindir}/nvidia-modprobe
%{_unitdir}/nvidia-device-setup.service

%changelog
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
