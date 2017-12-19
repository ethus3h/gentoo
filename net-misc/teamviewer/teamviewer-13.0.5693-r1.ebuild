# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

MY_PN=${PN}${PV/\.*}
inherit eutils gnome2-utils systemd

DESCRIPTION="All-In-One Solution for Remote Access and Support over the Internet"
HOMEPAGE="https://www.teamviewer.com"
SRC_URI="amd64? ( https://dl.tvcdn.de/download/linux/version_${PV/\.*}x/${PN}_${PV}_amd64.tar.xz )
		x86? ( https://dl.tvcdn.de/download/linux/version_${PV/\.*}x/${PN}_${PV}_i386.tar.xz )"

LICENSE="TeamViewer MIT"
SLOT="${PV/\.*}"
KEYWORDS="-* ~amd64 ~x86"
IUSE=""

DEPEND="sys-apps/sed"
RDEPEND="
	dev-qt/qtcore:5
	dev-qt/qtdbus:5
	dev-qt/qtdeclarative:5
	dev-qt/qtgui:5
	dev-qt/qtnetwork:5
	dev-qt/qtquickcontrols:5
	dev-qt/qtwebkit:5
	dev-qt/qtwidgets:5
	dev-qt/qtx11extras:5
	sys-apps/dbus
"

RESTRICT="bindist mirror"

# Silence QA messages
QA_PREBUILT="opt/${MY_PN}/*"

S="${WORKDIR}"/teamviewer

src_prepare() {
	default

	# Switch operation mode from 'portable' to 'installed'
	sed -e "s/TAR_NI/TAR_IN/g" -i tv_bin/script/tvw_config || die

	sed -e "/^ExecStart/s/${PN}/${MY_PN}/" \
		-i tv_bin/script/teamviewerd.service || die
}

src_install() {
	local dst="/opt/${MY_PN}" # install destination

	# Quirk:
	# Remove Intel 80386 32-bit ELF binary 'libdepend' present in all
	# archives. It will trip the 'emerge @preserved-libs' logic on amd64
	# when changing the ABI of one of its dependencies. According to the
	# TeamViewer devs, this binary is an unused remnant of previous Wine-
	# based builds and will be removed in future releases anyway
	rm tv_bin/script/libdepend

	insinto ${dst}
	doins -r tv_bin

	# Set permissions for executables and libraries
	for exe in $(find tv_bin -type f -executable -or -name '*.so'); do
		fperms 755 ${dst}/${exe}
	done

	newinitd "${FILESDIR}"/teamviewerd13.init teamviewerd${SLOT}
	systemd_newunit tv_bin/script/${PN}d.service ${PN}d${SLOT}.service

	insinto /usr/share/dbus-1/services
	doins tv_bin/script/com.teamviewer.TeamViewer.service
	doins tv_bin/script/com.teamviewer.TeamViewer.Desktop.service

	insinto /usr/share/polkit-1/actions
	doins tv_bin/script/com.teamviewer.TeamViewer.policy

	for size in 16 24 32 48 256; do
		newicon -s ${size} tv_bin/desktop/teamviewer_${size}.png TeamViewer.png
	done

	# Install documents (NOTE: using 'dodoc -r doc' instead of loop will
	# have the undesired result of installing subdirectory 'doc' in /usr/
	# share/doc/teamviewer-<version>)
	for doc in $(find doc -type f); do
		dodoc ${doc}
	done

	keepdir /etc/${MY_PN}
	dosym ../../etc/${MY_PN} ${dst}/config

	# Create directory and symlink for log files (NOTE: according to Team-
	# Viewer devs, all paths are hard-coded in the binaries; therefore
	# using the same path as the DEB/RPM archives, i.e. '/var/log/teamviewer
	# <major-version>')
	keepdir /var/log/${MY_PN}
	dosym ../../var/log/${MY_PN} ${dst}/logfiles

	dodir /opt/bin
	dosym ${dst}/tv_bin/teamviewerd /opt/bin/teamviewerd${SLOT}
	dosym ${dst}/tv_bin/script/teamviewer /opt/bin/${MY_PN}

	make_desktop_entry ${MY_PN} "TeamViewer ${SLOT}" TeamViewer
}

pkg_postinst() {
	gnome2_icon_cache_update

	elog "Please note that parallel installation of multiple versions of"
	elog "TeamViewer is currently not supported at runtime. Bug #621818"
	elog ""
	elog "Before using TeamViewer, you need to start its daemon:"
	elog "OpenRC:"
	elog "# /etc/init.d/teamviewerd${SLOT} start"
	elog "# rc-update add teamviewerd${SLOT} default"
	elog
	elog "Systemd:"
	elog "# systemctl start teamviewerd${SLOT}.service"
	elog "# systemctl enable teamviewerd${SLOT}.service"
	elog
	elog "To display additional command line options simply run:"
	elog "$ ${MY_PN} help"
}

pkg_postrm() {
	gnome2_icon_cache_update
}