module Initial_Conditions
  use constants, only : dl, twopi
  use Simulation, only : Lattice
  implicit none

contains

  !>@brief
  !> Given initialized condensate densities,
  !> rotate the phase of (ind)th condensate by phi
  subroutine rotate_condensate(this,dphi,ind)
    type(Lattice), intent(inout) :: this
    real(dl), intent(in) :: dphi
    integer, intent(in) :: ind

    real(dl) :: amp, phi
    integer :: i

    do i=1,this%nlat
       amp = sqrt(this%psi(i,1,ind)**2 + this%psi(i,2,ind)**2)
       phi = atan2(this%psi(i,2,ind),this%psi(i,1,ind)) + dphi
       this%psi(i,1,ind) = amp*cos(phi) 
       this%psi(i,2,ind) = amp*sin(phi)
    enddo
  end subroutine rotate_condensate

  !>@brief
  !> Given initialized condensates, imprint a global phase of dphi
  subroutine global_rotation(this,dphi)
    type(Lattice), intent(inout) :: this
    real(dl), intent(in) :: dphi

    real(dl) :: amp, phi
    integer :: i, l

    do l=1,this%nfld
       do i=1,this%nlat
          amp = sqrt(this%psi(i,1,l)**2+this%psi(i,2,l)**2)
          phi = atan2(this%psi(i,2,l),this%psi(i,1,l)) + dphi
          this%psi(i,1,l) = amp*cos(phi)
          this%psi(i,2,l) = amp*sin(phi)
       enddo
    enddo
  end subroutine global_rotation
  
  subroutine imprint_inhomogeneous_relative_phase(this,phi,i1,i2)
    type(Lattice), intent(inout) :: this
    real(dl), intent(in) :: phi
    integer, intent(in) :: i1,i2

    real(dl), dimension(1:this%nlat) :: rho
    
    ! Reset reference field to be purely imaginary
    this%psi(1:this%nlat,1,i1) = sqrt(this%psi(1:this%nlat,1,i1)**2+this%psi(1:this%nlat,2,i1)**2)
    this%psi(1:this%nlat,2,i1) = 0._dl

    rho = sqrt( this%psi(1:this%nlat,1,i2)**2 + this%psi(1:this%nlat,2,i2)**2 )
    this%psi(1:this%nlat,1,i2) = rho*cos(phi)
    this%psi(1:this%nlat,2,i2) = rho*sin(phi)
  end subroutine imprint_inhomogeneous_relative_phase
  
  subroutine imprint_relative_phase(this,phi,i1,i2)
    type(Lattice), intent(inout) :: this
    real(dl), intent(in) :: phi
    integer,intent(in) :: i1, i2
    real(dl) :: amp

    amp = 1._dl/2.**0.5
    
    this%psi(1:this%nlat,1,i1) = amp
    this%psi(1:this%nlat,2,i1) = 0._dl
    this%psi(1:this%nlat,1,i2) = amp*cos(phi)
    this%psi(1:this%nlat,2,i2) = amp*sin(phi)
  end subroutine imprint_relative_phase

  !>@brief
  !> Imprint a single-sine wave into the relative phase of two condensates
  !
  !>@param[inout] this - The lattice object whose fields we will modify
  !>@param[in] phi0 - Amplitude of mean variation
  !>@param[in] amp  - Amplitude of the sine wave
  !>@param[in] wn   - Wavenumber of the imprinted sine wave
  !>@param[in] i1   - First field in pair to give a relative phase
  !>@param[in] i2   - Second field in pair to give a relative phase
  !
  !@todo - Fix this to use grid xVals to imprint the wave (instead of dx)
  subroutine imprint_preheating_sine_wave(this, phi0, amp, wn, i1, i2)
    type(Lattice), intent(inout) :: this
    real(dl), intent(in) :: phi0, amp
    integer, intent(in) :: wn
    integer, intent(in) :: i1, i2

    real(dl), parameter :: rho_ave = 1._dl
    real(dl) :: knum
    integer :: n

    n = this%nLat
    knum = twopi*wn/this%lSize
    
    this%psi(1:n,1,i1) = sqrt(rho_ave)  ! Real part of psi_1
    this%psi(1:n,2,i1) = 0._dl          ! Imaginary part of psi_1
    this%psi(1:n,1,i2) = sqrt(rho_ave)*cos( phi0 + amp*sin(knum*this%xGrid(1:n)) )
    this%psi(1:n,2,i2) = sqrt(rho_ave)*sin( phi0 + amp*sin(knum*this%xGrid(1:n)) )
  end subroutine imprint_preheating_sine_wave
  
  subroutine imprint_gaussian(this, sig2)
    type(Lattice), intent(inout) :: this
    real(dl), intent(in) :: sig2

    integer :: i_

    this%psi = 0._dl
    do i_ = 1, this%nfld
       this%psi(1:this%nlat,1,i_) = exp(-0.5*this%xGrid**2/sig2)/(0.5_dl*twopi*sig2)**0.25 !* sqrt(2._dl)*this%xGrid
    enddo
  end subroutine imprint_gaussian

  subroutine imprint_sech_eigen(this, m)
    type(Lattice), intent(inout) :: this
    integer, intent(in) :: m
    integer :: i_

    this%psi = 0._dl
    do i_ = 1,this%nfld
       select case (m)
       case (11)
          this%psi(:,1,i_) = -sqrt(1._dl-tanh(this%xGrid)**2)
       case (21) ! ground state for lam = 2
          this%psi(:,1,i_) = 1._dl-tanh(this%xGrid)**2
       case (22) ! first excited state for lam = 2
          this%psi(:,1,i_) = tanh(this%xGrid)*sqrt(1._dl-tanh(this%xGrid)**2)
       case default
          this%psi(:,1,i_) = -sqrt(1._dl-tanh(this%xGrid)**2)
       end select
    enddo
  end subroutine imprint_sech_eigen
   
  subroutine imprint_bright_soliton(this,eta,kappa)
    type(Lattice), intent(inout) :: this
    real(dl), intent(in) :: eta, kappa

    integer :: i_; real(dl) :: x
    
    this%psi = 0._dl

    do i_=1,this%nlat
       x = this%xGrid(i_)
       this%psi(i_,1,1) = eta/cosh(eta*x)*cos(kappa*x)
       this%psi(i_,2,1) = eta/cosh(eta*x)*sin(kappa*x)
    enddo

    ! mu is ???
  end subroutine imprint_bright_soliton

  subroutine imprint_gray_soliton(this,amp,phi)
    type(Lattice), intent(inout) :: this
    real(dl), intent(in) :: amp, phi

    real(dl) :: x0

    x0 = -4._dl
    this%psi = 0._dl

    this%psi(:,1,1) = amp*cos(phi)*tanh(amp*cos(phi)*(this%xGrid-x0))
    this%psi(:,2,1) = amp*sin(phi)

    ! mu is ????
  end subroutine imprint_gray_soliton
  
  subroutine imprint_mean_relative_phase(this,phase)
    type(Lattice), intent(inout) :: this
    real(dl), intent(in) :: phase

    real(dl) :: rho

    rho = 1._dl

    this%psi(:,1,1) = rho**0.5; this%psi(:,2,1) = 0._dl
    this%psi(:,1,2) = this%psi(:,1,1)*cos(phase)
    this%psi(:,2,2) = this%psi(:,1,1)*sin(phase)

    ! mu is g-nu around true vacuum
    ! mus is g+nu around false vacuum
  end subroutine imprint_mean_relative_phase

  subroutine imprint_sine(this, wave_num, amp)
    type(Lattice), intent(inout) :: this
    integer, intent(in) :: wave_num
    real(dl), intent(in) :: amp

    real(dl) :: dx
    integer :: i_

    dx = this%dx

    this%psi = 0._dl
    do i_=1,this%nlat
       this%psi(i_,1,1) = amp*sin(wave_num*twopi*(i_-1)*dx/this%lSize)
       this%psi(i_,2,2) = amp*cos(wave_num*twopi*(i_-1)*dx/this%lSize)
    enddo
  end subroutine imprint_sine
  
end module Initial_Conditions
