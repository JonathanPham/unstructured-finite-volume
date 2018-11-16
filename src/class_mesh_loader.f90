module class_mesh_loader

  ! import dependencies
  use iso_fortran_env, only : dp => real64
  use class_file     , only : file
  use class_string, only : string

  implicit none

  private
  public :: mesh_loader

  !-------------------------------------------------------------------!
  ! Derived type for mesh load
  !-------------------------------------------------------------------!
  
  type :: mesh_loader

     type(file) :: file ! mesh file

   contains

     ! Type bound procedure that returns all information needed for
     ! mesh creation
     procedure :: get_mesh_data

     ! Helper functions
     procedure :: find_tags
     procedure :: process_vertices
     !procedure :: process_elements
     
  end type mesh_loader

  !-------------------------------------------------------------------!
  ! interface to construct a mesh_loader
  !-------------------------------------------------------------------!

  interface mesh_loader
     module procedure create
  end interface mesh_loader

contains

  type(mesh_loader) function create(filename) result (this)
    
    type(character(*)), intent(in) :: filename

    this % file = file(filename)

  end function create
  
  !====================================================================!
  ! Supply all information needed to create a mesh object
  !====================================================================!

  subroutine get_mesh_data(this, &
       & num_vertices, vertices, vertex_numbers, vertex_tags, & 
       & num_edges, edge_vertices, num_edge_vertices, edge_tags, &
       & num_faces, face_vertices, num_face_vertices, face_tags, &
       & num_cells, cell_vertices, num_cell_vertices, cell_tags)

    ! Arguments
    class(mesh_loader)  , intent(in)   :: this

    integer , intent(out)              :: num_vertices
    real(dp), intent(out), allocatable :: vertices(:,:)
    integer , intent(out), allocatable :: vertex_numbers(:)
    integer , intent(out), allocatable :: vertex_tags(:)

    integer, intent(out)              :: num_faces
    integer, intent(out), allocatable :: face_vertices(:,:)
    integer, intent(out), allocatable :: num_face_vertices(:)
    integer, intent(out), allocatable :: face_tags(:)

    integer, intent(out)              :: num_edges
    integer, intent(out), allocatable :: edge_vertices(:,:)
    integer, intent(out), allocatable :: num_edge_vertices(:)
    integer, intent(out), allocatable :: edge_tags(:)

    integer, intent(out)              :: num_cells
    integer, intent(out), allocatable :: cell_vertices(:,:)
    integer, intent(out), allocatable :: num_cell_vertices(:)
    integer, intent(out), allocatable :: cell_tags(:)

    ! Local
    type(string), allocatable, dimension(:) :: lines    
    
    ! Mesh tag
    integer :: idx_start_mesh
    integer :: idx_end_mesh

    ! Physical_Names tag    
    integer :: idx_start_physical_names
    integer :: idx_end_physical_names

    ! Nodes tag
    integer :: idx_start_nodes
    integer :: idx_end_nodes

    ! Elements tag
    integer :: idx_start_elements
    integer :: idx_end_elements

    write(*,'(a,a)') "Loading mesh file : ", this % file % filename
    
    ! Load the mesh into memory
    call this % file % read_lines(lines)
    ! call lines % print()  

    write(*,'(a)') "Identifying tags..."
    call this % find_tags(lines, &
         & idx_start_mesh           , idx_end_mesh  , &
         & idx_start_physical_names , idx_end_physical_names , &
         & idx_start_nodes          , idx_end_nodes, &
         & idx_start_elements       , idx_end_elements)
    write(*,'(a,i8,i8)') "mesh           : " , idx_start_mesh           , idx_end_mesh
    write(*,'(a,i8,i8)') "physical names : " , idx_start_physical_names , idx_end_physical_names
    write(*,'(a,i8,i8)') "nodes          : " , idx_start_nodes          , idx_end_nodes
    write(*,'(a,i8,i8)') "elements       : " , idx_start_elements       , idx_end_elements   

    write(*,'(a)') "Reading vertices... "        
    call this % process_vertices(lines(idx_start_nodes+2:idx_end_nodes-1), &
         & num_vertices, vertices, vertex_numbers, vertex_tags)
    write(*,'(a,i8)') "number of vertices", num_vertices

    ! process elements

    deallocate(lines)

  end subroutine get_mesh_data

  pure subroutine find_tags(this, lines, &
       & idx_start_mesh           , idx_end_mesh  , &
       & idx_start_physical_names , idx_end_physical_names , &
       & idx_start_nodes          , idx_end_nodes, &
       & idx_start_elements       , idx_end_elements)
    
    ! Arguments
    class(mesh_loader) , intent(in) :: this
    type(string)       , intent(in) :: lines(:)

    ! Mesh tag
    integer, intent(out) :: idx_start_mesh
    integer, intent(out) :: idx_end_mesh

    ! Physical_Names tag    
    integer, intent(out) :: idx_start_physical_names
    integer, intent(out) :: idx_end_physical_names

    ! Nodes tag
    integer, intent(out) :: idx_start_nodes
    integer, intent(out) :: idx_end_nodes

    ! Elements tag
    integer, intent(out) :: idx_start_elements
    integer, intent(out) :: idx_end_elements

    character(len=*), parameter :: BEGIN_MESH           = "$MeshFormat"
    character(len=*), parameter :: END_MESH             = "$EndMeshFormat"  
    character(len=*), parameter :: BEGIN_PHYSICAL_NAMES = "$PhysicalNames"
    character(len=*), parameter :: END_PHYSICAL_NAMES   = "$EndPhysicalNames"    
    character(len=*), parameter :: BEGIN_NODES          = "$Nodes"
    character(len=*), parameter :: END_NODES            = "$EndNodes"  
    character(len=*), parameter :: BEGIN_ELEMENTS       = "$Elements"
    character(len=*), parameter :: END_ELEMENTS         = "$EndElements"  

    integer :: num_lines, iline
    
    ! Extract start and end indices of different mesh tags used by
    ! GMSH
    num_lines = size(lines)
    do concurrent(iline = 1:num_lines)

       ! Find mesh start and end
       if (index(lines(iline) % str, BEGIN_MESH) .eq. 1) then
          idx_start_mesh = iline
       end if
       if (index(lines(iline) % str, END_MESH) .eq. 1) then
          idx_end_mesh = iline
       end if

       ! Find physical_names start and end
       if (index(lines(iline) % str, BEGIN_PHYSICAL_NAMES) .eq. 1) then
          idx_start_physical_names = iline
       end if
       if (index(lines(iline) % str, END_PHYSICAL_NAMES) .eq. 1) then
          idx_end_physical_names = iline
       end if

       ! Find nodes start and end
       if (index(lines(iline) % str, BEGIN_NODES) .eq. 1) then
          idx_start_nodes = iline
       end if
       if (index(lines(iline) % str, END_NODES) .eq. 1) then
          idx_end_nodes = iline
       end if

       ! Find elements start and end
       if (index(lines(iline) % str, BEGIN_ELEMENTS) .eq. 1) then
          idx_start_elements = iline
       end if
       if (index(lines(iline) % str, END_ELEMENTS) .eq. 1) then
          idx_end_elements = iline
       end if

    end do

  end subroutine find_tags
  
  pure subroutine process_vertices(this, lines, &
       & num_vertices, vertices, &
       & vertex_numbers, vertex_tags)
    
    ! Arguments
    class(mesh_loader) , intent(in)               :: this
    type(string)       , intent(in)               :: lines(:)
    integer            , intent(out)              :: num_vertices
    real(dp)           , intent(out), allocatable :: vertices(:,:)
    integer            , intent(out), allocatable :: vertex_numbers(:)
    integer            , intent(out), allocatable :: vertex_tags(:)

    ! Process nodes
    process_nodes: block
      
      integer                   :: iline
      integer                   :: num_tokens
      integer                   :: ivertex
      type(string), allocatable :: tokens(:)

      ! Set the number of vertices
      num_vertices = size(lines)
      allocate(vertices(3, num_vertices))
      allocate(vertex_numbers(num_vertices))
      
      ! Parse lines and store vertices
      do concurrent(ivertex=1:num_vertices)

         ! Get the numbers of tokens and tokens
         call lines(ivertex) % tokenize(" ", num_tokens, tokens)

         ! First token is the vertex number
         vertex_numbers(ivertex) = tokens(1) % asinteger()

         ! Second, third and fourth token are the coordinates
         vertices(:,ivertex) = tokens(2:) % asreal()

      end do

      if (allocated(tokens)) deallocate(tokens)

      ! Determine tags?
      
    end block process_nodes

  end subroutine process_vertices

end module class_mesh_loader
