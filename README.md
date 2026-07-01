# Roteiro de Instalação — Gentoo Linux
### Positivo VAIO VJFE59F11X · Ryzen 7 5700U · Radeon Renoir

---

## Fase 0 — Preparação

### 0.1 Boot no ambiente live
Use o LiveCD oficial do Gentoo (minimal install ou admincd). Confirme rede ativa:

```bash
ping -c 3 gentoo.org
```

### 0.2 Particionamento

Layout sugerido para o NVMe de 512GB:

| Partição | Tamanho | Tipo | Ponto de montagem |
|---|---|---|---|
| `/dev/nvme0n1p1` | 1GB | EFI System (FAT32) | `/boot` |
| `/dev/nvme0n1p2` | restante | BTRFS | `/` (com subvolumes) |

```bash
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart boot fat32 1MiB 1025MiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart root btrfs 1025MiB 100%

mkfs.vfat -F32 /dev/nvme0n1p1
mkfs.btrfs -L gentoo /dev/nvme0n1p2
```

### 0.3 Subvolumes BTRFS

```bash
mount /dev/nvme0n1p2 /mnt/gentoo

btrfs subvolume create /mnt/gentoo/@root
btrfs subvolume create /mnt/gentoo/@home
btrfs subvolume create /mnt/gentoo/@var

umount /mnt/gentoo

# Remontar usando o subvolume @root como raiz
mount -o subvol=@root,compress=zstd,noatime /dev/nvme0n1p2 /mnt/gentoo

mkdir -p /mnt/gentoo/{home,var,boot}
mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p2 /mnt/gentoo/home
mount -o subvol=@var,compress=zstd,noatime  /dev/nvme0n1p2 /mnt/gentoo/var
mount /dev/nvme0n1p1 /mnt/gentoo/boot
```

---

## Fase 1 — Stage3 e chroot

### 1.1 Baixar e extrair o stage3

Escolha o stage3 **systemd** (não OpenRC), já que decidimos por systemd como init:

```bash
cd /mnt/gentoo
links https://www.gentoo.org/downloads/mirrors/
# localizar: stage3-amd64-systemd-<data>.tar.xz

tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo
```

### 1.2 Configurar make.conf, repos.conf e diretórios `/etc/portage`

Copie todos os arquivos já decididos nesta conversa para dentro do novo sistema, **antes do chroot**:

```bash
mkdir -p /mnt/gentoo/etc/portage/{package.use,package.env,env,package.accept_keywords,package.mask,package.unmask,repos.conf,sets}
```

Cole o conteúdo de cada arquivo conforme consolidamos:

**Portage:**
- `/mnt/gentoo/etc/portage/make.conf`
- `/mnt/gentoo/etc/portage/repos.conf/gentoo.conf`
- `/mnt/gentoo/etc/portage/repos.conf/cachyos.conf`
- `/mnt/gentoo/etc/portage/package.use/00-base`
- `/mnt/gentoo/etc/portage/package.use/10-multimedia`
- `/mnt/gentoo/etc/portage/package.use/20-gnome`
- `/mnt/gentoo/etc/portage/package.use/30-network`
- `/mnt/gentoo/etc/portage/package.use/40-audio`
- `/mnt/gentoo/etc/portage/package.use/50-gaming`
- `/mnt/gentoo/etc/portage/package.use/60-development`
- `/mnt/gentoo/etc/portage/package.env`
- `/mnt/gentoo/etc/portage/env/gcc.env`
- `/mnt/gentoo/etc/portage/env/clang-lto.env`
- `/mnt/gentoo/etc/portage/env/no-optimize.env`
- `/mnt/gentoo/etc/portage/package.accept_keywords/10-kernel`
- `/mnt/gentoo/etc/portage/package.accept_keywords/20-gnome`
- `/mnt/gentoo/etc/portage/package.accept_keywords/30-rust-deps`
- `/mnt/gentoo/etc/portage/package.mask/10-gnome-extras`
- `/mnt/gentoo/etc/portage/package.mask/20-bloat`
- `/mnt/gentoo/etc/portage/package.mask/30-x11-leftovers`
- `/mnt/gentoo/etc/portage/package.unmask/10-cachyos`
- `/mnt/gentoo/etc/portage/package.unmask/20-gnome-rust`
- `/mnt/gentoo/etc/portage/sets/base-world`

**Sistema:**
- `/mnt/gentoo/etc/doas.conf`
- `/mnt/gentoo/etc/fstab`
- `/mnt/gentoo/etc/systemd/zram-generator.conf`
- `/mnt/gentoo/var/cache/ccache/ccache.conf`

Garantir permissões corretas do ccache e doas:

```bash
mkdir -p /mnt/gentoo/var/cache/ccache
chown -R portage:portage /mnt/gentoo/var/cache/ccache
chmod 600 /mnt/gentoo/etc/doas.conf
```

> **Importante:** no `make.conf`, mantenha as linhas `CC=clang` etc. **comentadas** por enquanto. O bootstrap inicial precisa do GCC do stage3.

### 1.3 Copiar DNS e entrar no chroot

```bash
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"

mount /boot
```

---

## Fase 2 — Dentro do chroot: base do sistema

### 2.1 Sincronizar Portage e overlay CachyOS

```bash
emerge-webrsync
emerge --sync --quiet

emerge app-eselect/eselect-repository
eselect repository enable cachyos
emaint sync --repo cachyos
```

### 2.2 Selecionar o perfil

```bash
eselect profile list
eselect profile set default/linux/amd64/23.0/desktop/systemd
```

### 2.3 CPU flags — otimizações SIMD específicas do Ryzen 5700U

Instale a ferramenta que lê diretamente o CPUID do processador:

```bash
emerge app-portage/cpuid2cpuflags
cpuid2cpuflags
```

A saída vai ser algo como:

```
CPU_FLAGS_X86: aes avx avx2 f16c fma3 mmx mmxext pclmul popcnt rdrand sha sse sse2 sse3 sse4_1 sse4_2 sse4a ssse3
```

Cole o resultado no `00-base`, junto com o policykit:

```bash
# /etc/portage/package.use/00-base
# necessário para o GDM e gnome-control-center funcionarem corretamente
# sem ele, ações que exigem privilégio (trocar config de rede, etc) falham silenciosamente
*/* policykit
*/* CPU_FLAGS_X86: aes avx avx2 f16c fma3 mmx mmxext pclmul popcnt rdrand sha sse sse2 sse3 sse4_1 sse4_2 sse4a ssse3
```

> As CPU flags habilitam otimizações SIMD em pacotes como FFmpeg, Mesa, libvpx e codecs de áudio. Precisam estar definidas antes de qualquer compilação real de pacotes de multimídia.

### 2.4 Definir fuso horário e locale

```bash
echo "America/Sao_Paulo" > /etc/timezone
emerge --config sys-libs/timezone-data

nano /etc/locale.gen
# descomentar:
# pt_BR.UTF-8 UTF-8
# en_US.UTF-8 UTF-8

locale-gen
eselect locale list
eselect locale set pt_BR.utf8

env-update && source /etc/profile
```

### 2.5 ccache — instalar o pacote

O `ccache.conf` já foi copiado para `/var/cache/ccache/` antes do chroot. Só falta o binário:

```bash
emerge dev-util/ccache
```

### 2.6 tmpfs para compilação

Edite `/etc/fstab` (provisório, dentro do chroot) e monte imediatamente:

```bash
echo 'tmpfs /var/tmp/portage tmpfs uid=portage,gid=portage,mode=775,nosuid,nodev,size=16G 0 0' >> /etc/fstab
mount /var/tmp/portage
```

---

## Fase 3 — Kernel CachyOS

```bash
emerge sys-kernel/cachyos-settings sys-kernel/cachyos-kernel sys-kernel/linux-firmware
```

O `cachyos-kernel` já vem com config pré-ajustada. Confirme o kernel instalado:

```bash
eselect kernel list
ls /boot
```

---

## Fase 4 — Bootstrap do toolchain Clang

> Esta fase usa GCC (do stage3) para compilar o Clang. **Não altere `CC`/`CXX` no make.conf ainda.**

```bash
emerge sys-devel/llvm sys-devel/clang sys-devel/lld
```

Depois de concluído, **agora sim** descomente no `make.conf`:

```bash
CC="clang"
CXX="clang++"
AR="llvm-ar"
NM="llvm-nm"
RANLIB="llvm-ranlib"
LDFLAGS="-fuse-ld=lld"
```

Reconstrua a base do sistema já com Clang:

```bash
emerge -uND @world
```

> Se algo quebrar com erros do tipo `undeclared identifier '__builtin_*'`, adicione o pacote ao `/etc/portage/package.env` apontando para `gcc.env`, conforme já documentamos, e rode novamente (o `--keep-going` evita que isso pare tudo).

---

## Fase 5 — Sistema base, boot e rede

### 5.1 GRUB

```bash
emerge sys-boot/grub sys-boot/efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --removable
grub-mkconfig -o /boot/grub/grub.cfg
```

### 5.2 fstab — confirmar UUIDs

O `/etc/fstab` veio do seu repositório, mas os UUIDs precisam bater com as partições reais desta instalação. Confirme e ajuste se necessário:

```bash
blkid
cat /etc/fstab
```

O formato esperado:

```fstab
UUID=<uuid-boot>   /boot       vfat    defaults,noatime                    0 2
UUID=<uuid-btrfs>  /           btrfs   subvol=@root,compress=zstd,noatime  0 0
UUID=<uuid-btrfs>  /home       btrfs   subvol=@home,compress=zstd,noatime  0 0
UUID=<uuid-btrfs>  /var        btrfs   subvol=@var,compress=zstd,noatime   0 0

tmpfs /var/tmp/portage tmpfs uid=portage,gid=portage,mode=775,nosuid,nodev,size=16G 0 0
```

### 5.3 Hostname e rede

```bash
echo "gentoo-vaio" > /etc/hostname

emerge net-misc/networkmanager net-wireless/wpa_supplicant
systemctl enable NetworkManager
```

### 5.4 Senha root e usuário

```bash
passwd

useradd -m -G users,wheel,audio,video,usb -s /bin/bash guilherme
passwd guilherme

# doas — substituto minimalista do sudo
emerge app-admin/doas sys-auth/polkit

```

---

## Fase 6 — zram, systemd e elogind

```bash
emerge sys-fs/zram-generator sys-auth/elogind
```

Configurar `/etc/systemd/zram-generator.conf`:

```ini
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
```

```bash
systemctl enable systemd-resolved   # opcional, se quiser via systemd
```

---

## Fase 7 — GNOME

```bash
emerge gnome-base/gnome-shell gnome-base/gdm gnome-base/gnome-session \
       gnome-base/gnome-settings-daemon gnome-base/gnome-control-center \
       x11-wm/mutter

emerge x11-misc/nautilus app-terminal/gnome-console app-editors/gnome-text-editor \
       media-gfx/loupe app-text/papers app-misc/gnome-calculator \
       sys-fs/gnome-disk-utility app-arch/file-roller sys-process/gnome-system-monitor \
       app-misc/gnome-maps media-video/cheese gnome-extra/gnome-tweaks gui-libs/seahorse

emerge sys-apps/xdg-desktop-portal sys-apps/xdg-desktop-portal-gnome

systemctl enable gdm
```

### 7.1 Áudio

```bash
emerge media-video/pipewire media-video/wireplumber
```

### 7.2 Vídeo / Mesa

```bash
emerge media-libs/mesa media-libs/libva media-libs/vulkan-loader
```

Confirme aceleração funcionando após o primeiro boot:

```bash
vulkaninfo --summary
vainfo
```

---

## Fase 8 — Gaming

```bash
emerge sys-apps/flatpak games-util/gamemode media-libs/libsdl2

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.valvesoftware.Steam
flatpak install flathub com.github.tchx84.Flatseal
```

Após o primeiro login gráfico, configure no Flatseal o acesso da Steam ao diretório onde você migrar sua biblioteca de jogos do NixOS.

---

## Fase 9 — Desenvolvimento web

```bash
emerge dev-lang/python dev-vcs/git net-libs/nodejs
```

---

## Fase 10 — Utilitários finais

```bash
emerge app-shells/fish app-misc/tmux net-misc/openssh sys-fs/dosfstools \
       app-arch/unzip app-arch/zip sys-apps/pciutils sys-apps/usbutils \
       app-portage/gentoolkit app-portage/eix app-portage/elogv app-editors/micro
```

---

## Fase 11 — Finalização

```bash
exit                       # saindo do chroot
cd /
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo
reboot
```

---

## Pós-instalação — checklist de verificação

- [ ] `systemctl status gdm` — login gráfico ativo
- [ ] `wpctl status` — PipeWire reconhecendo dispositivos de áudio
- [ ] `nmcli device wifi list` — Wi-Fi funcionando
- [ ] `vulkaninfo --summary` — Vulkan via RADV ativo
- [ ] `vainfo` — VA-API funcionando (decode de vídeo)
- [ ] `zramctl` — zram ativo
- [ ] Flatpak Steam reconhecendo a biblioteca de jogos migrada
- [ ] `elogv` — revisar avisos pós-instalação acumulados
- [ ] `eix-update && eix --version` — índice de pacotes funcionando

---

## Notas finais

- **Touchpad:** se o problema de botões físicos do Pixart aparecer novamente (como ocorreu no NixOS), o fix é via quirk de udev/hwdb equivalente ao `AttrEventCode=+BTN_RIGHT`, adaptado para `/etc/udev/hwdb.d/` no Gentoo.
- **LTO seletivo:** lembre de aplicar o `clang-lto.env` nos pacotes já mapeados (mesa, llvm, zstd, libsdl2) somente depois que o sistema estiver estável — não na primeira passada.
- **revdep-rebuild:** rode periodicamente após updates grandes, especialmente trocando entre GCC/Clang em pacotes específicos:
  ```bash
  revdep-rebuild
  ```
