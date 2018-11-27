!=====================================================================!
! Test loading of mesh and mesh pre-processing
!=====================================================================!

program test_mesh

  use iso_fortran_env   , only : dp => REAL64
  use class_gmsh_loader , only : gmsh_loader
  use class_mesh        , only : mesh
  use class_assembler   , only : assembler, solve_conjugate_gradient

  implicit none
  
  character(len=*)  , parameter   :: filename = "rectangle-100.msh"
  class(gmsh_loader), allocatable :: gmsh_loader_obj
  class(mesh)       , allocatable :: mesh_obj

  ! Solution parameters
  real(dp) , parameter   :: max_tol = 1.0d-8
  integer  , parameter   :: max_it = 100
  real(dp) , allocatable :: x(:)
  class(assembler), allocatable :: FVMAssembler
  integer :: npts
  
  ! Create a mesh object
  allocate(gmsh_loader_obj, source =  gmsh_loader(filename))
  allocate(mesh_obj, source = mesh(gmsh_loader_obj))
  deallocate(gmsh_loader_obj)

  ! Create an assembler object for assembling the linear system
  ! Geometry and meshing
  allocate(FVMAssembler, source = assembler(mesh_obj))

  npts = FVMAssembler % num_state_vars
  
  ! Create a solver object to solve the linear system  
  allocate(x(npts))
  call random_number(x)
  print *, 'xinit', x
  call solve_conjugate_gradient(FVMAssembler, max_it, max_tol, x)
  print *, 'solution', x

  ! Writes the mesh for tecplot
  call FVMassembler % write_solution("mesh.dat", x)

  deallocate(mesh_obj)
  deallocate(FVMAssembler)
  deallocate(x)

  contains

end program test_mesh
