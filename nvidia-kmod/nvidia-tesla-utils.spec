Name:           nvidia-tesla-utils
Epoch:          1
Version:        580.82.07
Release:        1.ludos%{?dist}
Summary:        NVIDIA Tesla datacenter driver user-space utilities

License:        Redistributable, no modification permitted
URL:            https://www.nvidia.com/
Source0:        nvidia-tesla-driver-%{version}.tar.xz

BuildArch:      x86_64
Requires:       nvidia-tesla-kmod-common = %{epoch}:%{version}-%{release}
Requires(post): %{_sbindir}/ldconfig
Requires(postun): %{_sbindir}/ldconfig

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
install -d %{buildroot}%{_mandir}/man1
install -d %{buildroot}%{_datadir}/doc/%{name}
install -d %{buildroot}%{_datadir}/licenses/%{name}
install -d %{buildroot}%{_sysconfdir}/nvidia

# Binaries
install -m 0755 usr/bin/nvidia-smi %{buildroot}%{_bindir}/
if [ -f usr/bin/nvidia-debugdump ]; then
    install -m 0755 usr/bin/nvidia-debugdump %{buildroot}%{_bindir}/
fi
if [ -f usr/bin/nvidia-bug-report.sh ]; then
    install -m 0755 usr/bin/nvidia-bug-report.sh %{buildroot}%{_bindir}/
fi

# Man pages (if available)
if [ -f usr/share/man/man1/nvidia-smi.1.gz ]; then
    install -m 0644 usr/share/man/man1/nvidia-smi.1.gz %{buildroot}%{_mandir}/man1/
fi
if [ -f usr/share/man/man1/nvidia-debugdump.1.gz ]; then
    install -m 0644 usr/share/man/man1/nvidia-debugdump.1.gz %{buildroot}%{_mandir}/man1/
fi

# Libraries required by nvidia-smi
for lib in libnvidia-ml.so libnvidia-cfg.so; do
    if compgen -G "usr/lib64/${lib}*" >/dev/null; then
        cp -a usr/lib64/${lib}* %{buildroot}%{_libdir}/
    fi
done

# Additional NVML ancillary data (if present)
if [ -d etc/nvidia/nvidia-application-profiles-rc.d ]; then
    cp -a etc/nvidia/nvidia-application-profiles-rc.d %{buildroot}%{_sysconfdir}/nvidia/
fi
if [ -f etc/nvidia/nvidia-application-profiles-rc ]; then
    install -m 0644 etc/nvidia/nvidia-application-profiles-rc %{buildroot}%{_sysconfdir}/nvidia/
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

%postun
%{_sbindir}/ldconfig

%files
%license %{_datadir}/licenses/%{name}/*
%doc %{_datadir}/doc/%{name}/*
%{_bindir}/nvidia-smi
%{_bindir}/nvidia-debugdump
%{_bindir}/nvidia-bug-report.sh
%{_mandir}/man1/nvidia-smi.1.gz
%{_mandir}/man1/nvidia-debugdump.1.gz
%{_libdir}/libnvidia-ml.so*
%{_libdir}/libnvidia-cfg.so*
%config(noreplace) %{_sysconfdir}/nvidia/nvidia-application-profiles-rc
%dir %{_sysconfdir}/nvidia
%{_sysconfdir}/nvidia/nvidia-application-profiles-rc.d

%changelog
* Fri Sep 26 2025 LudOS Project <ludos@example.com> - 1:580.82.07-1.ludos
- Initial packaging of NVIDIA Tesla user-space utilities for LudOS
- Provides nvidia-smi and NVML libraries alongside Tesla kmod packages
