package RSGL 

import "core:c"

when ODIN_OS == .Windows {
    @(extra_linker_flags="/NODEFAULTLIB:msvcrt")
		foreign import native {
			"lib/RSGL_msvc.lib",
		}
} else when ODIN_OS == .Darwin {
    foreign import native {
        "RSGL.a",
    }
} else when (ODIN_OS == .Linux || ODIN_OS == .FreeBSD || ODIN_OS == .OpenBSD) {
    foreign import native {
        "RSGL.a",
    }
}

MAX_BATCHES :: 2028
MAX_VERTS :: 8192

/* 
******
RSGL_debug
*****
*/

/*! @brief the type of debug message */
debugType :: enum(u8) {
	error = 0, warning, info
}

/*! @brief error codes for known failure types */
errorCode :: enum(u8){
	noError = 0, /*!< no error */
	errorBackend, 
	errorQueryFail,
	errorShader,
	infoBackend,
	infoShader,
	warningBackend
}

/*! @brief data for debug messages */
debugInfo :: struct {
	type: debugType, /*!< the type of message */
	code: errorCode, /*!< the code for the specific type of debug message */
	msg: cstring /*!< string message */
};

debugFunc :: proc "c" (#by_ptr info : debugInfo)

texture :: c.size_t
framebuffer :: c.size_t

textureFormat :: enum {
	formatNone = 0,
	formatRGB,    /*!< 8-bit RGB (3 channels) */
    formatBGR,    /*!< 8-bit BGR (3 channels) */
	formatRGBA,   /*!< 8-bit RGBA (4 channels) */
    formatBGRA,   /*!< 8-bit BGRA (4 channels) */
    formatRed,   /*!< 8-bit RED (1 channel) */
    formatGrayscale,   /*!< 8-bit grayscale (1 channel) */
    formatGrayscaleAlpha,   /*!< 8-bit grayscale alpha (1 channel) */
	formatCount
}

textureDataType :: enum {
	textureDataInt = 0,
	textureDataFloat
}

textureFilter :: enum { 
	filterNearest = 0,
	filterLinear
}

textureBlob :: struct {
	data : rawptr, /* input data */
	width : c.size_t, /* width of the texture */
	height : c.size_t, /* height of the texture */
	dataType : textureDataType,
	dataFormat : textureFormat, /* format of the input data */
	textureFormat : textureFormat, /* final format for the texture */
	minFilter : textureFilter, /* filter used when rendering a surface smaller than the base texture */
	magFilter : textureFilter/* filter used when rendering a surface bigger than the base texture */
}

/*
*******
RSGL shapes
*******
*/

rect :: struct { x, y, w, h : c.float }
cube :: struct { x, y, z, w, h, l : c.float }
vec2D :: [2]c.float 
vec3D :: [3]c.float 

/*
the color stucture is in
ABGR by default for performance reasons

converting color to hex for example
*/
color :: struct {
    a, b, g, r : u8
}

RGBA :: proc(r, g, b, a : u8) -> color { return  {a, b, g, r} }
RGB :: proc(r, g, b : u8) -> color { return  {255, b, g, r} }
BGR :: proc(b, g, r : u8) -> color { return  {255, b, g, r} }

mat4 :: struct {
    m : [16]c.float
}

/*
*******
perspective
*******
*/

projectionType :: enum {
	projectionOrtho2D = 0,
	projectionOrtho3D,
	projectionPerspective3D,
}

projection2D :: struct {
	type : projectionType,
	width : u32,
	height : u32
}

projection3D :: struct {
	type : projectionType,
	fov : c.float,
	ratio : c.float,
	pNear : c.float,
	pFar : c.float
}

projection :: struct #raw_union {
	type : projectionType,
	p2D : projection2D,
	p3D : projection3D 
}

/*
*********************
RSGL renderer
*********************
*/

/* used internally for deleteProgram */
shaderType :: enum {
	shaderTypeNone = 0,
	shaderTypeStandard = 1, /* standard vertex+fragment shader */
	shaderTypeCompute = 2,
	shaderTypeGeometry = 4, /* unimplemented as of now */
}

/* shader program and blob */
programBlob :: struct {
	vertex : cstring,
	vertexLen : c.size_t, 
	fragment : cstring, 
	fragmentLen : c.size_t 
}

programInfo :: struct {
    program : c.size_t,
	perspectiveView : c.size_t,
	model : c.size_t,
	vertexPosition : c.size_t,
	vertexTexCoord : c.size_t,
	vertexColor : c.size_t,
	type : shaderType
}

BATCH :: struct {
    start, len : c.size_t, /* when batch starts and it's length */
    elmStart : c.size_t, elmCount : c.size_t, /* when element batch starts and it's length */
    type : drawType, 
    tex : texture,
    lineWidth : c.float,
    mat : mat4
} /* batch data type for rendering */

renderData :: struct {
	verts : ^c.float,
	texCoords : ^c.float,
	colors : ^c.float,
	elements : ^u16,
	elements_count : c.size_t,
    len : c.size_t, /* number of verts */

	perspective : mat4, /* perspective matrix */
}

bufferType :: enum {
	arrayBuffer = 0,
	elementArrayBuffer,
	shaderStorageBuffer,
	textureBuffer,
	uniformBuffer
}

renderBuffers :: struct {
	vertex, color, texture, elements : c.size_t,
	maxVerts : c.size_t,

	batches : [MAX_BATCHES]BATCH,
    batchCount : c.size_t
}

renderState :: struct {
    gradient : ^c.float, /* does not allocate any memory */

	source : rect,
    tex : texture,
    gradient_len : u32,

	color : color,

    rotate : vec3D ,
	program : ^programInfo,
	buffers : ^ renderBuffers,

    center : vec3D,
    lineWidth : c.float,
	modelmat : mat4,
	viewmat : mat4,
	perspectivemat : mat4,
	forceBatch : bool,
	overflow : bool,
	framebuffer : framebuffer
}

renderPass :: struct {
	program : ^programInfo,
	mat : ^c.float,
	buffers : ^renderBuffers, 
	framebuffer : framebuffer
}

rendererProc :: struct {
	size : #type proc "c" () -> c.size_t, /* get the size of the renderer's internal struct */
	defaultBlob : #type proc "c" (ctx : rawptr) -> programBlob,
	initPtr : #type proc "c" (ctx : rawptr, procdef : rawptr), /* init render backend */
	freePtr : #type proc "c" (ctx : rawptr), /* free render backend */
	render : #type proc "c" (ctx : rawptr, pass : ^renderPass),
	clear : #type proc "c" (ctx : rawptr, framebuffer : framebuffer, r : c.float, g : c.float, b : c.float, a : c.float ),
	viewport : #type proc "c" (ctx : rawptr, x : i32, y : i32, w : i32, h : i32),
	setSurface : #type proc "c" (ctx : rawptr, surface : rawptr),
	createTexture : #type proc "c" (ctx : rawptr, blob : ^textureBlob) -> texture,
	copyToTexture : #type proc "c" (ctx : rawptr, tex : texture, x : c.size_t, y : c.size_t, blob : ^textureBlob),
	deleteTexture : #type proc "c" (ctx : rawptr, tex : texture),
	scissorStart : #type proc "c" (ctx : rawptr, x : c.float, y : c.float, w : c.float, h : c.float, renderer_height : c.float),
	scissorEnd : #type proc "c" (ctx : rawptr),
	createProgram : #type proc "c" (ctx : rawptr, blob : ^programBlob) -> programInfo,
	deleteProgram : #type proc "c" (ctx : rawptr, program : ^programInfo),
	findShaderVariable : #type proc "c" (rawptr, info : ^programInfo, name : cstring, length : c.size_t) -> c.size_t,
	updateShaderVariable : #type proc "c" (rawptr, ^programInfo, c.size_t, []c.float, u8),
	createComputeProgram : #type proc "c" (ctx : rawptr, CShaderCode : cstring) -> programInfo,
	dispatchComputeProgram : #type proc "c" (ctx : rawptr, program : ^programInfo, groups_x : u32, groups_y : u32, groups_z : u32),
	bindComputeTexture : #type proc "c" (ctx : rawptr, texture : u32, format : u8),
	createBuffer : #type proc "c" (ctx : rawptr, type : bufferType ,  size : c.size_t, data : rawptr, buffer : ^c.size_t),
	updateBuffer : #type proc "c" (ctx : rawptr, type : bufferType , buffer : c.size_t, data : rawptr, start : c.size_t, len : c.size_t),
	deleteBuffer : #type proc "c" (ctx : rawptr, buffer : c.size_t),
	createFramebuffer : #type proc "c" (ctx : rawptr, width : c.size_t, height : c.size_t) -> framebuffer,
	attachFramebuffer : #type proc "c" (ctx : rawptr, fbo : framebuffer, tex : texture, attachType : u8, mipLevel : u8),
	deleteFramebuffer : #type proc "c" (ctx : rawptr, fbo : framebuffer)
}

renderer :: struct {
	data : renderData,
	state : renderState,
	procdef : rendererProc,
	userPtr : rawptr,
	ctx : rawptr, /* pointer for the renderer backend to store any internal data it wants/needs  */

	defaultTexture : texture,
	defaultProgram : programInfo,
	defaultPerspectivemat : mat4,

    verts : [MAX_VERTS * 3]c.float ,
    texCoords : [MAX_VERTS * 2]c.float ,
    colors : [MAX_VERTS * 4]c.float ,
    elements : [MAX_VERTS * 6]u16,
	buffers : renderBuffers
}

/*
*******
draw low level
*******
*/

drawType :: enum {
	TRIANGLES = 0,
	POINTS = 1,
	LINES = 2
}

rawVerts :: struct {
	type : drawType,
	verts : ^c.float,
	texCoords : ^c.float,
	elements : ^u16,
	elmCount : c.size_t,
	vert_count : c.size_t
}

viewType :: enum {
	viewTypeNone = 0,
	viewType2D,
	viewType3D,
}

view2D :: struct{
	type : viewType,
	offset : vec3D,
	target : vec3D,
    rotation : c.float,
    zoom: c.float
}

/* RSGL translation */
view3D :: struct {
	type : viewType,
	pos : vec3D,
	target : vec3D,
    up : vec3D 
}

view :: struct #raw_union {
	type : viewType,
	view2D : view2D,
	view3D : view3D
} 

@(default_calling_convention="c", link_prefix="RSGL_")
foreign native {
    /* 
    ******
    RSGL_debug
    *****
    */

    setDebugCallback :: proc(func: debugFunc) -> debugFunc ---

    /*
    *********************
    RSGL matrix math
    *********************
    */

    mat4_loadIdentity:: proc() -> mat4 ---
    mat4_scale:: proc(matr : [16]c.float, x : c.float, y : c.float, z : c.float) -> mat4 ---
    mat4_rotate:: proc(mat: [16]c.float, angle : c.float, x : c.float, y : c.float, z : c.float) -> mat4 ---
    mat4_translate:: proc(matr: [16]c.float, x : c.float, y : c.float, z : c.float) -> mat4 ---
    mat4_perspective:: proc(mat: [16]c.float, fovY : c.float, aspect : c.float, zNear : c.float, zFar : c.float) -> mat4 ---
    mat4_ortho:: proc(mat: [16]c.float, left : c.float, right : c.float, bottom : c.float, top : c.float, znear : c.float, zfar : c.float) -> mat4 ---
    mat4_lookAt:: proc(mat : [16]c.float, eyeX : c.float, eyeY : c.float, eyeZ : c.float, targetX : c.float, targetY : c.float, targetZ : c.float, upX : c.float, upY : c.float, upZ : c.float) -> mat4 ---

    mat4_multiply:: proc(left : [16]c.float, right : [16]c.float) -> mat4 ---

    mat4_multiplyPoint:: proc(mat : mat4, point : vec3D) -> vec3D ---

    /*
    *******
    perspective
    *******
    */

    projection_getMatrix:: proc(projection : ^projection) -> mat4 ---

    /*
    *********************
    RSGL renderer
    *********************
    */

    renderer_getRenderState :: proc(renderer : ^renderer, state : ^renderState) ---

    renderer_size :: proc(renderer : ^renderer) -> c.size_t ---

    renderer_initPtr :: proc(procdef : rendererProc,
                            loader : rawptr, /* opengl prozc address ex. wglProcAddress */
                            ptr : rawptr, /* pointer to allocate backend data */
                            renderer : ^renderer
                        ) ---

    renderer_init :: proc(procdef : rendererProc, loader : rawptr) -> ^renderer ---
    renderer_updateSize :: proc(renderer : ^renderer, width : c.size_t, height : c.size_t) ---
    renderer_freePtr :: proc(renderer : ^renderer) ---

    renderer_setSurface:: proc(renderer : ^renderer, surface : rawptr) ---

    renderer_createBuffer:: proc(renderer : ^renderer, type : bufferType, size : c.size_t, data : rawptr, buffer : ^c.size_t) ---
    renderer_updateBuffer:: proc(renderer : ^renderer, type : bufferType, buffer : c.size_t, data : rawptr, start : c.size_t, len : c.size_t) ---
    renderer_deleteBuffer:: proc(renderer : ^renderer, buffer : c.size_t) ---

    renderer_createRenderBuffers:: proc(renderer : ^renderer, size : c.size_t, buffers : ^renderBuffers) ---
    renderer_deleteRenderBuffers:: proc(renderer : ^renderer, buffers : ^renderBuffers) ---

    renderer_render:: proc(renderer : ^renderer) --- /* draw current batch */
    renderer_updateRenderBuffers:: proc(renderer : ^renderer) ---
    renderer_renderBuffers:: proc(renderer : ^renderer) ---

    renderer_free:: proc(renderer : ^renderer) ---

    renderer_setRotate:: proc(renderer : ^renderer, rotate : vec3D) --- /* apply rotation to drawing */
    renderer_setTexture:: proc(renderer : ^renderer, tex : texture) --- /* apply texture to drawing */
    renderer_setTextureSource:: proc(renderer : ^renderer, tex : texture, rect : rect) --- /* apply texture to drawing (limited to the given rect) */
    renderer_setColor:: proc(renderer : ^renderer, color : color) --- /* apply color to drawing */
    renderer_setProgram:: proc(renderer : ^renderer, program : ^programInfo) --- /* use shader program for drawing */
    renderer_setFramebuffer:: proc(renderer : ^renderer, framebuffer : framebuffer) ---
    renderer_setRenderBuffers:: proc(renderer : ^renderer, buffers : ^renderBuffers) ---
    renderer_setGradient:: proc(renderer : ^renderer,
                                    gradient : ^c.float, /* array of gradients */
                                    len : c.size_t /* length of array */
                                ) --- /* apply gradient to drawing, based on color list*/
    renderer_setCenter:: proc(renderer : ^renderer, center : vec3D) --- /* the center of the drawing (or shape), this is used for rotation */
    renderer_setOverflow:: proc(renderer : ^renderer, overflow : bool) ---
    /* args clear after a draw function by default, this toggles that */
    renderer_clearArgs:: proc(renderer : ^renderer) --- /* clears the args */

    renderer_initDrawMatrix:: proc(renderer : ^renderer, center : vec3D) -> mat4 ---

    /* renders the current batches */
    renderer_clear:: proc(renderer : ^renderer, color : color) ---
    renderer_viewport:: proc(renderer : ^renderer, rect : rect) ---
    /* create a texture based on a given bitmap, this must be freed later using deleteTexture or opengl*/
    renderer_createTexture:: proc(renderer : ^renderer, blob : ^textureBlob) -> texture ---
    /* updates an existing texture wiht a new bitmap */
    renderer_copyToTexture:: proc(renderer : ^renderer, tex : texture,  x : c.size_t, y : c.size_t, blob : ^textureBlob) ---
    /* delete a texture */
    renderer_deleteTexture:: proc(renderer : ^renderer, tex : texture) ---
    renderer_createFramebuffer:: proc(renderer : ^renderer, width : c.size_t, height : c.size_t) -> framebuffer ---
    renderer_attachFramebuffer:: proc(renderer : ^renderer, fbo : framebuffer, tex : texture, attachType : u8, mipLevel : u8) ---
    renderer_deleteFramebuffer:: proc(renderer : ^renderer, fbo : framebuffer) ---
    /* starts scissoring */
    renderer_scissorStart:: proc(renderer : ^renderer, scissor : rect, height : i32) ---
    /* stops scissoring */
    renderer_scissorEnd:: proc(renderer : ^renderer) ---
    /* custom shader program */
    renderer_defaultBlob:: proc(ctx : ^renderer) -> programBlob ---
    renderer_createProgram:: proc(renderer : ^renderer, blob : ^programBlob) -> programInfo ---
    renderer_deleteProgram:: proc(renderer : ^renderer, program : ^programInfo) ---
    renderer_findShaderVariable:: proc(renderer : ^renderer, program : ^programInfo, var : cstring, len : c.size_t) -> c.size_t ---
    renderer_updateShaderVariable:: proc(renderer : ^renderer, program : ^programInfo, var : c.size_t, value : []c.float, len : u8) ---
    renderer_forceBatch:: proc(renderer : ^renderer) ---

    renderer_setPerspectiveMatrix:: proc(renderer : ^renderer, mat : mat4) ---
    renderer_setDefaultPerspectiveMatrix:: proc(renderer : ^renderer, mat : mat4) ---

    renderer_setModelMatrix:: proc(renderer : ^renderer, mat : mat4) ---
    renderer_resetModelMatrix:: proc(renderer : ^renderer) ---

    renderer_createComputeProgram:: proc(renderer : ^renderer, CShaderCode : cstring) -> programInfo ---
    renderer_dispatchComputeProgram :: proc(renderer : ^renderer, program : ^programInfo, groups_x : u32, groups_y : u32, groups_z : u32) ---
    renderer_bindComputeTexture :: proc(renderer : ^renderer, texture : c.size_t, format : u8) ---

    /*
    *******
    draw low level
    *******
    drawRawVerts is a function used internally by RSGL, but you can use it yourself
    drawRawVerts batches a given set of points based on th data to be rendered
    */

    drawRawVerts :: proc(renderer : ^renderer, data : ^rawVerts) -> i32 ---

    /*
    *******
    draw primitives
    *******
    */
    /* 2D shape drawing */
    /* in the function names, F means float */

    drawPoint :: proc(renderer : ^renderer, p : vec2D) -> i32 ---

    drawRect :: proc(renderer : ^renderer, r : rect) -> i32 ---

    drawRoundRect :: proc(renderer : ^renderer, r : rect, rounding : vec2D) -> i32 ---

    drawPolygon :: proc(renderer : ^renderer, r : rect, sides : u32) -> i32 ---

    drawArc :: proc(renderer : ^renderer, o : rect, arc : vec2D) -> i32 ---

    drawOval :: proc(renderer : ^renderer, o : rect) -> i32 ---

    drawLine :: proc(renderer : ^renderer, p1 : vec2D, p2 : vec2D, thickness : u32) -> i32 ---

    /* 3D objects */
    drawTriangle :: proc(renderer : ^renderer, triangle : [3]vec3D) -> i32 ---
    drawPoint3D :: proc(renderer : ^renderer, p : vec3D) -> i32 ---
    drawLine3D :: proc(renderer : ^renderer, p1 : vec3D, p2 : vec3D, thickness : u32) -> i32 ---
    drawCube :: proc(renderer : ^renderer, cube : cube) -> i32 ---

    /* 2D outlines */

    /* thickness means the thickness of the line */
    drawTriangleOutline :: proc(renderer : ^renderer, triangle : [3]vec3D, thickness : u32) -> i32 ---

    drawRectOutline :: proc(renderer : ^renderer, r : rect, thickness : u32) -> i32 ---

    drawRoundRectOutline :: proc(renderer : ^renderer, r : rect, rounding : vec2D, thickness : u32) -> i32 ---

    drawPolygonOutline :: proc(renderer : ^renderer, r : rect, sides : u32, thickness : u32) -> i32 ---

    drawArcOutline :: proc(renderer : ^renderer, o : rect, arc : vec2D, thickness : u32) -> i32 ---

    drawOvalOutline :: proc(renderer : ^renderer, o : rect, thickness : u32) -> i32 ---

    /*
    *******
    view
    *******
    */

    view_getMatrix :: proc(view : ^view) -> mat4 --- 
}