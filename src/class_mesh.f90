!=====================================================================!
! Unstructured mesh handler.
! 
! Author: Komahan Boopathy (komahan@gatech.edu)
!=====================================================================!

module class_mesh

  use iso_fortran_env       , only : dp => REAL64, error_unit
  use interface_mesh_loader , only : mesh_loader    
  use module_mesh_utils
  
  implicit none

  private
  public :: mesh
  
  ! Constructor
  interface mesh
     module procedure create_mesh
  end interface mesh

  !-------------------------------------------------------------------! 
  ! Mesh datatype. A collection of vertices, cells and faces.
  !-------------------------------------------------------------------!
  
  type :: mesh ! rename as topology?

     logical :: initialized = .false.

     !================================================================!
     ! Basic Topology information
     !================================================================!

     ! Fundamental vertex info
     integer :: num_vertices
     real(dp) , allocatable :: vertices(:,:)             ! [[x,y,z],1:nvertices]
     integer  , allocatable :: vertex_numbers(:)
     integer  , allocatable :: vertex_tags(:)

     ! Fundamental face info
     integer :: num_edges
     integer  , allocatable :: edge_numbers(:)
     integer  , allocatable :: edge_tags(:)
     integer  , allocatable :: edge_vertices(:,:)        ! [[v1,v2],1:nedges]
     integer  , allocatable :: num_edge_vertices(:)

     ! Fundamental face info
     integer :: num_faces
     integer  , allocatable :: face_numbers(:)          
     integer  , allocatable :: face_tags(:)          
     integer  , allocatable :: face_vertices(:,:)        ! [[v1,v2],1:nfaces]
     integer  , allocatable :: num_face_vertices(:)

     ! Fundamental cell info
     integer :: num_cells
     integer  , allocatable :: cell_numbers(:)
     integer  , allocatable :: cell_tags(:)
     integer  , allocatable :: cell_vertices(:,:)   ! [[v1,v2,v3], 1:ncells]
     integer  , allocatable :: num_cell_vertices(:) ! [1:ncells]

     !================================================================!
     ! Derived Topology information
     !================================================================!
     
     ! Inverse cell information
     integer  , allocatable :: vertex_cells(:,:)    ! [[c1,c2,c3],[1:nvertices]]
     integer  , allocatable :: num_vertex_cells(:)  ! [1:nvertices]
     
     ! Inverse face information
     integer  , allocatable :: vertex_faces(:,:)    ! [[f1,f2,f3],[1:nfaces]]
     integer  , allocatable :: num_vertex_faces(:)  ! [1:nfaces]

     ! Inverse edge information
     integer  , allocatable :: vertex_edges(:,:)    ! [[e1,e2,e3],[1:nedges]]
     integer  , allocatable :: num_vertex_edges(:)  ! [1:nedges]

     ! Intermidiate connectivities and their inverse
     integer  , allocatable :: num_cell_faces(:)         ! [1:ncells]
     integer  , allocatable :: cell_faces(:,:)           ! [[f1,f2,f3..],1:ncells]
     integer  , allocatable :: num_face_cells(:)         ! [1:nfaces]
     integer  , allocatable :: face_cells(:,:)           ! [[c1,c2...],1:nfaces]
     
     ! Intermidiate connectivities and their inverse
     integer  , allocatable :: num_face_edges(:)         ! [1:nfaces]
     integer  , allocatable :: face_edges(:,:)           ! [[e1,e2,e3..],1:nfaces]
     integer  , allocatable :: num_edge_faces(:)         ! [1:nedges]
     integer  , allocatable :: edge_faces(:,:)           ! [[f1,f2...],1:nedges]
     
     !================================================================!
     ! Derived Geometry information
     !================================================================!
     
     ! Derived cell info
     real(dp) , allocatable :: cell_centers(:,:)         ! [[x,y,z] , 1:ncells]
     real(dp) , allocatable :: cell_volumes(:)           ! [1:ncells]

     ! Derived vertex info
     real(dp) , allocatable :: face_centers(:,:)         ! [[x,y,z],1:nfaces]
     real(dp) , allocatable :: face_areas(:)             ! [1:nfaces]
     real(dp) , allocatable :: face_deltas(:)             ! [1:nfaces]
     real(dp) , allocatable :: lvec(:,:)                 ! [[lx,ly,lz],1:nfaces]     
  
     real(dp) , allocatable :: cell_face_tangents(:,:,:) ! [[tx,ty,tz], [f1,f2,f3..] 1:ncells]
     real(dp) , allocatable :: cell_face_normals(:,:,:)  ! [[nx,ny,nz], [f1,f2,f3..] 1:ncells]          
    
     real(dp) , allocatable :: vertex_cell_weights(:,:)  ! [[wc1,wc2...],1:vertices]
     real(dp) , allocatable :: face_cell_weights(:,:)    ! [[wc1,wc2],1:nfaces]
     
     ! Generalize to tag numbers. Right now we can't differentiate
     ! lower face from upper face.
     integer  :: num_boundary_faces
     integer  , allocatable :: boundary_face_face(:)      ! [1:num_boundary_faces]
     integer  , allocatable :: is_face_boundary_face(:)   ! [1:num_faces]
     integer  , allocatable :: is_node_boundary_node(:)   ! [1:num_vertices]
     
   contains

     ! Type bound procedures
     procedure :: to_string
     procedure :: initialize

     ! Evaluation routines
     procedure :: evaluate_cell_centers
     procedure :: evaluate_cell_volumes     
     procedure :: evaluate_face_centers_areas
     procedure :: evaluate_face_tangents_normals
     procedure :: evaluate_centroidal_vector
     procedure :: evaluate_face_deltas
     procedure :: evaluate_face_weight
     procedure :: evaluate_vertex_weight

     ! Destructor
     ! final   :: destruct
     
  end type mesh

contains

  !================================================================!
  ! Constructor for mesh object using mesh loader
  !================================================================!
  
  type(mesh) function create_mesh(loader) result(me)

    ! Arguments
    class(mesh_loader), intent(in) :: loader
    
    ! Get the fundamental information needed 
    call loader % get_mesh_data( &
         & me % num_vertices, me % vertex_numbers, me % vertex_tags , me % vertices ,  & 
         & me % num_edges   , me % edge_numbers  , me % edge_tags   , me % edge_vertices , me % num_edge_vertices , &
         & me % num_faces   , me % face_numbers  , me % face_tags   , me % face_vertices , me % num_face_vertices , &
         & me % num_cells   , me % cell_numbers  , me % cell_tags   , me % cell_vertices , me % num_cell_vertices   &
         & )

    ! Check allocations and print error messages and stop

    ! Sanity check (make sure numbering is continuous), although it may not start from one
    if (me % num_vertices .gt. 0 .and. &
         & maxval(me % vertex_numbers) -  minval(me % vertex_numbers) + 1 .ne. me % num_vertices) &
         & error stop
    if (me % num_edges    .gt. 0 .and. &
         & maxval(me % edge_numbers  ) -  minval(me % edge_numbers  ) + 1 .ne. me % num_edges   ) &
         & error stop
    if (me % num_faces    .gt. 0 .and. &
         & maxval(me % face_numbers  ) -  minval(me % face_numbers  ) + 1 .ne. me % num_faces   ) &
         & error stop
    if (me % num_cells    .gt. 0 .and. &
         & maxval(me % cell_numbers  ) -  minval(me % cell_numbers  ) + 1 .ne. me % num_cells   ) &
         & error stop

    call me % to_string()

    ! Perform initialization tasks and store the resulting flag
    me % initialized = me % initialize()
    if (me % initialized .eqv. .false.) then
       write(error_unit,*) "Mesh.Construct: failed"
       error stop
    end if
    
    call me % to_string()

  end function create_mesh
  
  type(logical) function initialize(this)

    class(mesh), intent(inout) :: this

    !-----------------------------------------------------------------!
    ! Find VertexCell conn. by inverting CellVertex conn.
    !-----------------------------------------------------------------!

    vertex_cell: block

      integer :: ivertex
      
      write(*,*) "Inverting CellVertex Map..."
      call reverse_map( &
           & this % cell_vertices, &
           & this % num_cell_vertices, &
           & this % vertex_cells, &
           & this % num_vertex_cells)      

      if (allocated(this % vertex_cells)) then

         write(*,'(a,i4,a,i4)') &
              & "Vertex to cell info for", min(10,this % num_vertices), &
              & " vertices out of ", this % num_vertices

         do ivertex = 1, min(10,this % num_vertices)
            write(*,*) &
                 & 'vertex ', this % vertex_numbers(ivertex), &
                 & 'num_vertex_cells ', this % num_vertex_cells(ivertex) ,&
                 & 'cells ', this % vertex_cells(1:this % num_vertex_cells(ivertex),ivertex)
         end do

         ! Sanity check
         if (minval(this % num_vertex_cells) .lt. 1) then
            write(error_unit, *) 'Error: There are vertices not mapped to a cell'
            error stop
         end if

      else

         write(*,'(a)') "Vertex to cell info not computed"

      end if
      
    end block vertex_cell

    !-----------------------------------------------------------------!
    ! Find VertexFace conn. by inverting FaceVertex conn.
    !-----------------------------------------------------------------!

    vertex_face: block

      integer :: ivertex
      
      write(*,*) "Inverting FaceVertex Map..."
      call reverse_map( &
           & this % face_vertices, &
           & this % num_face_vertices, &
           & this % vertex_faces, &
           & this % num_vertex_faces)      

      if (allocated(this % vertex_faces)) then

         write(*,'(a,i4,a,i4)') &
              & "Vertex to face info for", min(10,this % num_vertices), &
              & " vertices out of ", this % num_vertices

         do ivertex = 1, min(10,this % num_vertices)
            write(*,*) &
                 & 'vertex ', this % vertex_numbers(ivertex), &
                 & 'num_vertex_faces ', this % num_vertex_faces(ivertex) ,&
                 & 'faces ', this % vertex_faces(1:this % num_vertex_faces(ivertex),ivertex)
         end do

         ! Sanity check
         if (minval(this % num_vertex_faces) .lt. 1) then
            write(error_unit, *) 'Error: There are vertices not mapped to a face'
            error stop
         end if

      else

         write(*,'(a)') "Vertex to face info not computed"

      end if

    end block vertex_face

    !-----------------------------------------------------------------!
    ! Find VertexEdge conn. by inverting EdgeVertex conn.
    !-----------------------------------------------------------------!

    vertex_edge: block

      integer :: ivertex

      write(*,*) "Inverting EdgeVertex Map..."

      call reverse_map( &
           & this % edge_vertices, &
           & this % num_edge_vertices, &
           & this % vertex_edges, &
           & this % num_vertex_edges)      
      
      if (allocated(this % vertex_edges)) then

         write(*,'(a,i4,a,i4)') &
              & "Vertex to edge info for", min(10,this % num_vertices), &
              & " vertices out of ", this % num_vertices

         do ivertex = 1, min(10,this % num_vertices)
            write(*,*) &
                 & 'vertex ', this % vertex_numbers(ivertex), &
                 & 'num_vertex_edges ', this % num_vertex_edges(ivertex) ,&
                 & 'edges ', this % vertex_edges(1:this % num_vertex_edges(ivertex),ivertex)
         end do

         ! Sanity check
         if (minval(this % num_vertex_edges) .lt. 1) then
            write(error_unit, *) 'Error: There are vertices not mapped to a edge'
            error stop
         end if
         
      else

         write(*,'(a)') "Vertex to edge info not computed"

      end if

    end block vertex_edge

    !-----------------------------------------------------------------!
    ! Find Cell Face conn. by combining two maps
    !-----------------------------------------------------------------!

    cell_face: block
      
      integer :: icell

      write(*,*) "Combining CellVertex with VertexFace to get CellFace Map..."
      
      ! Combine maps to get cell_faces
      call get_cell_faces(this % cell_vertices, &
           & this % vertex_faces, this % num_vertex_faces, &
           & this % cell_faces, this % num_cell_faces)

      if (allocated(this % cell_faces)) then

         write(*,'(a,i4,a,i4)') &
              & "Cell to face info for", min(10,this % num_cells), &
              & " cells out of ", this % num_cells

         do icell = 1, min(10,this % num_cells)
            write(*,*) &
                 & 'cell'  , icell, &
                 & 'nfaces', this % num_cell_faces(icell), &
                 & 'faces' , this % cell_faces(1:this % num_cell_faces(icell),icell)
         end do

      else

         write(*,'(a)') "Vertex to edge info not computed"

      end if

    end block cell_face

    !-----------------------------------------------------------------!
    ! Find Face Cell conn. by inverting Cell Face conn.    
    !-----------------------------------------------------------------!
   
    face_cell : block
      
      integer :: iface

      ! Invert cell_faces
      call reverse_map(this % cell_faces, this % num_cell_faces, &
           & this % face_cells, this % num_face_cells)

      do iface = 1, this % num_faces
         print *, 'face', iface, 'cells', this % face_cells(1:this%num_face_cells(iface),iface)
      end do
      
      if (minval(this % num_face_cells) .lt. 1) then
         write(error_unit, *) 'Error: There are faces not mapped to a cell'
      end if
      
    end block face_cell
    
    !-----------------------------------------------------------------!
    ! Identify boundary faces, nodes
    !-----------------------------------------------------------------!
    
    boundary : block

      integer :: iface, ivertex

      write(*,*) "Identifying boundary faces"

      ! Form boundary faces from faces with 1 boundary
      call get_boundary_faces(this % num_face_cells, this % boundary_face_face)
      print *, this % boundary_face_face

      ! Find if a face is boundary face (Tag faces with index) face_tags
      ! [t1,t2,1:nfaces]
      allocate(this % is_face_boundary_face(this % num_faces))
      do iface = 1, this % num_faces
         if ( is_subset([iface], [this % boundary_face_face]) .eqv. .true.) then
            this % is_face_boundary_face(iface) = 1
         else
            this % is_face_boundary_face(iface) = 0
         end if
      end do

      ! Find if a node is boundary node (node tag)
      allocate(this % is_node_boundary_node(this % num_vertices))
      do ivertex = 1, this % num_vertices
         if (is_subset([ivertex], &
              & [this % face_vertices(:,this % boundary_face_face)]) &
              & .eqv. .true.) then
            this % is_node_boundary_node(ivertex) = 1
         else
            this % is_node_boundary_node(ivertex) = 0
         end if
      end do

    end block boundary
        
    !-----------------------------------------------------------------!
    ! Evaluate all geometric quantities needed for FVM assembly
    !-----------------------------------------------------------------!

    geom : block

      integer :: icell, iface

      write(*,*) 'Calculating mesh geometry information'

      call this % evaluate_cell_centers()
      call this % evaluate_face_centers_areas()
      call this % evaluate_face_tangents_normals()
      call this % evaluate_cell_volumes()

      call this % evaluate_centroidal_vector()
      call this % evaluate_face_deltas()
      call this % evaluate_face_weight()   
      call this % evaluate_vertex_weight()    

    end block geom

   ! Signal that all tasks are complete
   initialize = .true.

 end function initialize
  
  subroutine evaluate_vertex_weight(this)

    class(mesh), intent(inout) :: this
    integer,  allocatable :: cells(:)
    real(dp) :: total, dcell
    integer  :: icell, ivertex

    write(*,*) 'Evaluating face weights for interpolation from cells to vertex'

    allocate(cells(maxval(this % num_vertex_cells)))

    allocate( &
         & this % vertex_cell_weights( &
         & 1:maxval(this % num_vertex_cells), &
         & this % num_faces) &
         & )
    this % vertex_cell_weights = 0

    do ivertex = 1, this % num_vertices

       cells(1:this % num_vertex_cells(ivertex)) = &
            & this % vertex_cells(1:this % num_vertex_cells(ivertex), ivertex)

       total  = 0.0d0

       do icell = 1, this % num_vertex_cells(ivertex)

          dcell = distance(this % cell_centers(:,icell), this % vertices(:,ivertex))

          this % vertex_cell_weights(icell,ivertex) = 1.0_dp/dcell

          total = total + this % vertex_cell_weights(icell,ivertex)

       end do

       this % vertex_cell_weights(:,ivertex) = this % vertex_cell_weights(:,ivertex)/total

       print *, "vertex", ivertex, this % vertex_cell_weights(1:this % num_vertex_cells(ivertex),ivertex)

    end do

  end subroutine evaluate_vertex_weight

  subroutine evaluate_face_weight(this)

    class(mesh), intent(inout) :: this
    integer  :: iface
    integer  :: cellindex1, cellindex2
    real(dp) :: xcellcenter1(3), xcellcenter2(3), xfacecenter(3)
    real(dp) :: d1, d2
    real(dp) :: dinv1, dinv2
    real(dp) :: weight

    write(*, *) 'Evaluating face weights for interpolation from cells to face'
    allocate(this % face_cell_weights(2, this % num_faces))      

    !do concurrent(iface = 1: this % num_faces)

    do iface = 1, this % num_faces

       cellindex1   = this % face_cells(1, iface)
       xcellcenter1 = this % cell_centers(:, cellindex1)
       xfacecenter  = this % face_centers(:,iface)       
       d1           = distance(xcellcenter1, xfacecenter)
       dinv1        = 1.0_dp/d1

       ! Extract the second cell if this is not a boundary face
       if (this % is_face_boundary_face(iface) .ne. 1) then
          cellindex2   = this % face_cells(2, iface)
          xcellcenter2 = this % cell_centers(:, cellindex2)
          d2           = distance(xcellcenter2, xfacecenter)
          dinv2        = 1.0_dp/d2
       else
          dinv2        = 0.0_dp                    
       end if

       weight       = dinv1/(dinv1+dinv2)

       this % face_cell_weights(1:2,iface) = [weight,1.0_dp - weight]

       print *, "face weight", iface, this % face_cell_weights(1:2,iface)

    end do

  end subroutine evaluate_face_weight

  subroutine evaluate_face_deltas(this)

    class(mesh), intent(inout) :: this
    integer  :: gface, gcell, lface
    real(dp) :: fn(3)

    write(*,*) "Evaluating face deltas"
    allocate(this % face_deltas(this % num_faces))

    do gface = 1, this % num_faces

       ! First cell belonging to the face
       gcell = this % face_cells(1, gface)

       ! Face number in local numbering
       lface = find(this % cell_faces(:,gcell), gface)

       ! Index into normal array
       fn =  this % cell_face_normals(:, lface, gcell)

       ! Take absolute value of dot product
       this % face_deltas(gface) = abs(dot_product(this % lvec(1:3,gface), fn))

       print *, "face", gface, "delta", this % face_deltas(gface), &
            & "skewness", dot_product(this % lvec(1:3,gface), &
            & this % cell_face_tangents(:, lface, gcell)), &
            & dot_product(this % cell_face_tangents(:, lface, gcell), &
            & this % cell_face_normals(:, lface, gcell))

    end do

    ! Check for negative volumes
    if (abs(minval(this % face_deltas)) .lt. > 1.0d-10) then
       print *, 'collinear faces/bad cell?'
       error stop
    end if

  end subroutine evaluate_face_deltas

  subroutine evaluate_centroidal_vector(this)

    class(mesh), intent(inout) :: this
    integer :: iface, cells(2)

    write (*,*) "Evaluating centroidal vector..."

    allocate(this % lvec(3,this % num_faces))

    do iface = 1, this % num_faces

       cells = 0
       cells(1:this%num_face_cells(iface)) = this % face_cells(1:this%num_face_cells(iface),iface)

       if (this % is_face_boundary_face(iface) .eq. 1) then
          ! Boundary faces .or. iface is in bfaces
          this % lvec(:,iface) = this % face_centers(:,iface) - this % cell_centers(:,cells(1))        
       else
          ! Interior face; subtract neighbouring cell centers (not sure which orientation)
          this % lvec(:,iface) = this % cell_centers(:,cells(2)) - this % cell_centers(:,cells(1))          
       end if

    end do

  end subroutine evaluate_centroidal_vector

  subroutine evaluate_cell_volumes(this)

    class(mesh), intent(inout) :: this

    ! Use divergence theorem to find volumes
    integer :: lcell, lface, gface
    
    write (*,*) "Evaluating cell volumes..."

    allocate(this % cell_volumes (this % num_cells))
    this % cell_volumes = 0_dp      

    ! V = \sum_f nx_f \times  xmid_f \times A_f
    do lcell = 1, this % num_cells
       this % cell_volumes(lcell) = 0.0d0
       do lface = 1, this % num_cell_faces(lcell)
          ! Global face index
          gface = this % cell_faces(lface, lcell)
          associate( &
               & xmid => this % face_centers(1,gface), &
               & nx   => this % cell_face_normals(1,lface,lcell),&
               & area => this % face_areas(gface))
          this % cell_volumes(lcell) = this % cell_volumes(lcell) + &
               & nx*xmid*area              
        end associate
     end do
  end do

  ! Check for negative volumes
  if (minval(this % cell_volumes) .lt. 0) then
     print *, 'negative volume encountered'
     error stop
  end if
  
end subroutine evaluate_cell_volumes

  subroutine evaluate_face_centers_areas(this)

    class(mesh), intent(inout) :: this

    ! Currently the length as its a 1D face
    type(integer) :: iface

    write(*, *) 'Evaluating face centers and areas'

    allocate(this % face_areas(this % num_faces))
    allocate(this % face_centers(3,this % num_faces))         

    do concurrent(iface = 1 : this % num_faces)

       ! Area calculation is complicated in 3D
       associate(facenodes => this % face_vertices(:,iface))

         ! Compute the coordinates of face centers
       this % face_centers(1:3, iface) = &
            & sum(this % vertices(1:3, facenodes),dim=2)/&
            & real(2,kind=dp) ! this face has 2 edges

       associate(v1 => this % vertices(:,facenodes(1)), &
            & v2 => this % vertices(:,facenodes(2))  )

         ! Compute face areas
       this % face_areas(iface) = distance(v1, v2)

        end associate
       
      end associate

   end do

   ! Check for zero areas
   if (abs(minval(this % face_areas)) .lt. 10.0d0*tiny(1.0d0)) then
      print *, 'same points/bad face?'
      error stop
   end if
   
 end subroutine evaluate_face_centers_areas
 
  subroutine evaluate_cell_centers(this)

    class(mesh), intent(inout) :: this

     ! Find cell centers O = (A + B + C) /3
    type(integer) :: icell

    write(*,*) 'Evaluating cell centers'
    
    !print *, 'num_vertices for each cell', this % num_cell_vertices

    allocate(this % cell_centers(3, this % num_cells))
    
    do concurrent(icell = 1 : this % num_cells)
       this % cell_centers(:, icell) = sum(&
            & this % vertices(&
            & :, this % cell_vertices(&
            & 1:this % num_cell_vertices(icell),icell)&
            & ), dim=2)&
            & /real(this % num_cell_vertices(icell), kind=dp)
    end do
    
  end subroutine evaluate_cell_centers
  
  subroutine evaluate_face_tangents_normals(this)

    class(mesh), intent(inout) :: this

    integer  :: icell, iface, gface
    real(dp) :: t(3), n(3), tcn(3) ! all spatial dim
    integer  :: ifv(2)

    write(*,*) 'Evaluating face tangents normals'
    
    allocate(this % cell_face_normals (3, maxval(this % num_cell_faces), this % num_cells))
    allocate(this % cell_face_tangents(3, maxval(this % num_cell_faces), this % num_cells))

    ! loop cells
    do icell = 1, this % num_cells

       ! get cell verties
       associate( icv =>  this % cell_vertices(:, icell) ) 

       ! loop faces of each cell
       do iface = 1, this % num_cell_faces(icell)

          if (iface .eq. this % num_cell_faces(icell)) then
             ifv(1) = icv(iface)
             ifv(2) = icv(1)
          else
             ifv(1) = icv(iface)
             ifv(2) = icv(iface+1)               
          end if

          ! find the face vertex in cell order                       
          gface = this % cell_faces(iface,icell)

          t = this % vertices(:,ifv(2)) - this % vertices(:,ifv(1))
          t = t/norm2(t)

          ! By anticlockwise convention
          n(1) =  t(2)
          n(2) = -t(1)
          n(3) = 0

          ! Sanity check if the normal if facing out of the face
          call cross_product(n,t,tcn)
          if (abs(tcn(3) - 1.0d0) > 1.0d-10) then ! tangent cross normal should give +k vector
             print *, 'face', gface, 'of cell', icell, 'has inward/non-unit normal', tcn(3)
             error stop
          end if

          this % cell_face_normals (:, iface, icell) = n
          this % cell_face_tangents(:, iface, icell) = t
          
       end do

       end associate

    end do
    
  end subroutine evaluate_face_tangents_normals

  !===================================================================!
  ! Constructor for mesh creation
  !===================================================================!
  
  subroutine to_string(this)

    class(mesh), intent(in) :: this

    integer :: icell, ivertex, iface, iedge

    write(*,*) 'Number of vertices :', this % num_vertices
    write(*,*) 'Number of cells    :', this % num_cells
    write(*,*) 'Number of faces    :', this % num_faces
    
    if (this % num_vertices .gt. 0) then
       write(*,'(a,i4,a,i4)') "Vertex info for ", min(10,this % num_vertices), &
            & ' vertices out of ', this % num_vertices
       write(*,*) "number tag x y z"
       do ivertex = 1, min(10,this % num_vertices)
          write(*,'(i6,i2,3E15.6)') &
               & this % vertex_numbers(ivertex), &
               & this % vertex_tags(ivertex), &
               & this % vertices(:, ivertex)
       end do
    end if

    if (this % num_cells .gt. 0) then
       write(*,'(a,i4,a,i4)') "Cell info for ", min(10,this % num_cells), &
            & ' cells out of ', this % num_cells
       write(*,*) "cno ctag ncv iverts"
       do icell = 1, min(10,this % num_cells)
          write(*,'(i6,i2,i2,10i6)') &
               & this % cell_numbers(icell), &
               & this % cell_tags(icell), &
               & this % num_cell_vertices(icell), &
               & this % cell_vertices(1:this % num_cell_vertices(icell), icell)
       end do
    end if

    if (this % num_faces .gt. 0) then
       write(*,'(a,i4,a,i4)') "Face info for ", min(10,this % num_faces), &
            & ' faces out of ', this % num_faces       
       write(*,*) "fno ftag nfv iverts"
       do iface = 1, min(10,this % num_faces)
          write(*,'(i6,i2,i2,10i6)') &
               & this % face_numbers(iface), &
               & this % face_tags(iface), &
               & this % num_face_vertices(iface), &
               & this % face_vertices(1:this % num_face_vertices(iface), iface)
       end do
    end if

    if (this % num_edges .gt. 0) then    
       write(*,'(a,i4,a,i4)') "Edge info for ", min(10,this % num_edges), &
            & ' edges out of ', this % num_edges
       write(*,*) "eno etag nev iverts"
       do iedge = 1, min(10,this % num_edges)
          write(*,'(i6,i2,i2,10i6)') &
               & this % edge_numbers(iedge), &
               & this % edge_tags(iedge), &
               & this % num_edge_vertices(iedge), &
               & this % edge_vertices(1:this % num_edge_vertices(iedge), iedge)
       end do
    end if
    
    if (this % initialized .eqv. .true.) then
       
       write(*,*) "Cell Geo. Data [index] [center] [volume]"
       do icell = 1, this % num_cells
          write(*,*) &
               & "local number [", this % cell_numbers(icell)   ,"]", &
               & "center [", this % cell_centers(:,icell) ,"]", &
               & "volume [", this % cell_volumes(icell)   ,"]"
       end do

       write(*,*) "Face Data [index] [center] [area]"
       do iface = 1, this % num_faces
          write(*,*) &
               & "local number [",iface,"]", &
               & "face center [",this % face_centers(:, iface),"]", &
               & "face deltas [",this % face_deltas(iface),"]", &                              
               & "face areas [",this % face_areas(iface),"]", &
               & "face lvec  [",this % lvec(:,iface),"]"
       end do

    end if

  end subroutine to_string
  
end module class_mesh
