# GPU Compute Node Setup

## NVIDIA GPU

To install the NVIDIA driver, you must install the necessary utilities and dependencies from their official repository. For more information, see this [guide](https://docs.rockylinux.org/desktop/display/installing_nvidia_gpu_drivers/) and the [NVIDIA's CUDA installation guide](https://docs.nvidia.com/cuda/pdf/CUDA_Installation_Guide_Linux.pdf).

To verify if the compute node has CUDA-capable GPU.

``` sh
NODE='n5' # change this to a GPU compute node
sudo wwctl ssh "${NODE}" lspci | grep -i nvidia
```

> If there is no output `NVIDIA`, try the command `update-pciids` to update the PCI hardware database.

> If the graphics card is from NVIDIA and it is listed [here](https://developer.nvidia.com/cuda-gpus), the
GPU is CUDA-capable.

### Installing NVIDIA GPU Drivers

Create a separate image for GPU compute nodes. Copy the `rockylinux-8` image to a new image.

``` sh
sudo wwctl container copy rockylinux-8 rockylinux-8-gpu
```

Run a shell inside a newly created image `rockylinux-8-gpu` for the GPU compute nodes.

``` sh
sudo wwctl container shell 'rockylinux-8-gpu'
```

Install necessary utilities and dependencies.

``` sh
dnf install -y epel-release
dnf groupinstall -y 'Development Tools'
dnf install -y kernel-devel dkms
```

Install NVIDIA GPU drivers.

``` sh
dnf config-manager --add-repo "http://developer.download.nvidia.com/compute/cuda/repos/rhel8/$(uname -i)/cuda-rhel8.repo"
dnf install -y kernel-headers kernel-devel tar bzip2 make automake gcc gcc-c++ pciutils elfutils-libelf-devel libglvnd-opengl libglvnd-glx libglvnd-devel acpid pkgconf dkms
dnf module install -y nvidia-driver:latest-dkms
```

Remove build dependencies to prevent the image from becoming too large to boot properly. Install them only when upgrading the NVIDIA GPU drivers.

``` sh
dnf groupremove -y 'Development Tools'
```

[Nouveau](https://nouveau.freedesktop.org/) is an open-source NVIDIA driver that provides limited functionality compared to NVIDIA's proprietary drivers. It is best to disable it to avoid driver conflicts.

``` sh
printf '%s\n%s\n' 'blacklist nouveau' 'options nouveau modeset=0' > /etc/modprobe.d/blacklist-nouveau.conf
```

Exit Warewulf container shell with 0 exit status to force a rebuild.

``` sh
exit 0
```

Set the image of GPU compute nodes to `rockylinux-8-gpu`.

``` sh
NODE='n5' # change this to a GPU compute node
sudo wwctl node set "${NODE}" --container='rockylinux-8-gpu'
sudo wwctl node list -a "${NODE}" # verify
# ... repeat for other GPU compute nodes
```

Always rebuild overlays manually after changes to the cluster. Then, reboot the nodes.

``` sh
sudo wwctl overlay build
```
