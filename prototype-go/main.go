package main

/*
#cgo LDFLAGS: -framework ApplicationServices -framework Foundation -lobjc
#include <ApplicationServices/ApplicationServices.h>
#include <objc/runtime.h>
#include <objc/message.h>

CGEventRef mouseMovedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    if (type == kCGEventMouseMoved || type == kCGEventLeftMouseDragged || type == kCGEventRightMouseDragged) {
        CGPoint loc = CGEventGetLocation(event);
        *((double*)userInfo) = loc.x;
        *((double*)userInfo + 1) = loc.y;
    }
    return event;
}

int isNil(void *p) {
    return p == NULL;
}

CGPoint getCurrentMousePosition() {
    CGEventRef event = CGEventCreate(NULL);
    CGPoint cursor = CGEventGetLocation(event);
    CFRelease(event);
    return cursor;
}

void makeWindowClickThrough(void* windowPtr) {
    Class nsWindowClass = objc_getClass("NSWindow");
    SEL sel = sel_registerName("setIgnoresMouseEvents:");
    ((void (*)(id, SEL, BOOL))objc_msgSend)((id)windowPtr, sel, 1);
}

void hideDockIcon() {
    id app = ((id (*)(id, SEL))objc_msgSend)(
        (id)objc_getClass("NSApplication"),
        sel_registerName("sharedApplication")
    );
    // NSApplicationActivationPolicyAccessory = 1
    ((void (*)(id, SEL, long))objc_msgSend)(app, sel_registerName("setActivationPolicy:"), 1);
}
*/
import "C"
import (
	"flag"
	"fmt"
	"math"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"unsafe"

	"github.com/go-gl/gl/v3.3-core/gl"
	"github.com/go-gl/glfw/v3.3/glfw"
)

type point struct{ x, y float32 }

// monitorWin хранит GLFW-окно и OpenGL-объекты для одного монитора.
type monitorWin struct {
	win          *glfw.Window
	x, y         int // позиция монитора в глобальных логических координатах
	w, h         int // логический размер монитора
	program      uint32
	vao, vbo     uint32
}

var (
	trailLength = flag.Int("trail-length", 80, "длина хвоста (кол-во точек)")
	lineWidth   = flag.Float64("line-width", 60, "максимальная толщина линии")
	debugMode   = flag.Bool("debug", false, "включить debug-логирование")
)

func init() { runtime.LockOSThread() }

func dist(x1, y1, x2, y2 float64) float64 {
	dx, dy := x1-x2, y1-y2
	return math.Sqrt(dx*dx + dy*dy)
}

func compileShader(source string, shaderType uint32) (uint32, error) {
	shader := gl.CreateShader(shaderType)
	csources, free := gl.Strs(source)
	gl.ShaderSource(shader, 1, csources, nil)
	free()
	gl.CompileShader(shader)

	var status int32
	gl.GetShaderiv(shader, gl.COMPILE_STATUS, &status)
	if status == gl.FALSE {
		var logLength int32
		gl.GetShaderiv(shader, gl.INFO_LOG_LENGTH, &logLength)
		log := make([]byte, logLength)
		gl.GetShaderInfoLog(shader, logLength, nil, &log[0])
		return 0, fmt.Errorf("compile error: %s", log)
	}
	return shader, nil
}

func createProgram() (uint32, error) {
	vertexShaderSrc := `
	#version 330 core
	layout (location = 0) in vec2 aPos;
	layout (location = 1) in float aAlpha;
	out float vAlpha;
	void main() {
		gl_Position = vec4(aPos, 0.0, 1.0);
		vAlpha = aAlpha;
	}`

	fragmentShaderSrc := `
#version 330 core
in float vAlpha;
out vec4 FragColor;

void main() {
    float gradientFactor = smoothstep(0.0, 1.0, vAlpha);
    gradientFactor = pow(gradientFactor, 0.15);

    vec3 startColor = vec3(0.6, 0.1, 0.0);
    vec3 earlyColor = vec3(0.9, 0.3, 0.0);
    vec3 midColor   = vec3(1.0, 0.6, 0.1);
    vec3 endColor   = vec3(1.0, 1.0, 0.4);

    vec3 color;
    if (gradientFactor < 0.33) {
        color = mix(startColor, earlyColor, gradientFactor * 3.0);
    } else if (gradientFactor < 0.66) {
        color = mix(earlyColor, midColor, (gradientFactor - 0.33) * 3.0);
    } else {
        color = mix(midColor, endColor, (gradientFactor - 0.66) * 3.0);
    }

    FragColor = vec4(color, vAlpha * 0.9);
}
`
	vs, err := compileShader(vertexShaderSrc+"\x00", gl.VERTEX_SHADER)
	if err != nil {
		return 0, err
	}
	fs, err := compileShader(fragmentShaderSrc+"\x00", gl.FRAGMENT_SHADER)
	if err != nil {
		return 0, err
	}
	program := gl.CreateProgram()
	gl.AttachShader(program, vs)
	gl.AttachShader(program, fs)
	gl.LinkProgram(program)
	gl.DeleteShader(vs)
	gl.DeleteShader(fs)
	return program, nil
}

// initEventTap регистрирует CGEventTap и запускает CFRunLoop в горутине.
// coords должен жить в вызывающей функции — передаётся указатель в C-колбэк.
func initEventTap(coords *[2]C.double) {
	tap := C.CGEventTapCreate(
		C.kCGHIDEventTap,
		C.kCGHeadInsertEventTap,
		C.kCGEventTapOptionListenOnly,
		(1<<C.kCGEventMouseMoved)|
			(1<<C.kCGEventLeftMouseDragged)|
			(1<<C.kCGEventRightMouseDragged),
		(C.CGEventTapCallBack)(unsafe.Pointer(C.mouseMovedCallback)),
		unsafe.Pointer(&coords[0]),
	)
	if C.isNil(unsafe.Pointer(tap)) != 0 {
		fmt.Println("Не удалось создать event tap — добавьте бинарь в Accessibility.")
		os.Exit(1)
	}
	source := C.CFMachPortCreateRunLoopSource(C.CFAllocatorRef(unsafe.Pointer(uintptr(0))), tap, 0)
	C.CFRunLoopAddSource(C.CFRunLoopGetCurrent(), source, C.kCFRunLoopCommonModes)
	C.CGEventTapEnable(tap, C.bool(true))
	go C.CFRunLoopRun()
}

// initWindows создаёт по одному прозрачному окну на каждый монитор.
// Первый монитор инициализирует GL; остальные используют shared-контекст.
func initWindows() []monitorWin {
	if err := glfw.Init(); err != nil {
		panic(err)
	}

	glfw.WindowHint(glfw.ContextVersionMajor, 3)
	glfw.WindowHint(glfw.ContextVersionMinor, 3)
	glfw.WindowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile)
	glfw.WindowHint(glfw.OpenGLForwardCompatible, glfw.True)
	glfw.WindowHint(glfw.Decorated, glfw.False)
	glfw.WindowHint(glfw.TransparentFramebuffer, 1)
	glfw.WindowHint(glfw.Floating, 1)
	glfw.WindowHint(glfw.Resizable, glfw.False)

	monitors := glfw.GetMonitors()
	wins := make([]monitorWin, 0, len(monitors))

	var glInitialized bool

	for i, m := range monitors {
		mx, my := m.GetPos()
		mode := m.GetVideoMode()

		// Второй и последующие окна разделяют GL-контекст с первым.
		var share *glfw.Window
		if len(wins) > 0 {
			share = wins[0].win
		}

		win, err := glfw.CreateWindow(mode.Width, mode.Height, "Comet Cursor", nil, share)
		if err != nil {
			panic(err)
		}
		win.SetPos(mx, my)
		C.makeWindowClickThrough(win.GetCocoaWindow())

		if i == 0 {
			C.hideDockIcon()
		}

		win.MakeContextCurrent()
		glfw.SwapInterval(1)

		if !glInitialized {
			if err := gl.Init(); err != nil {
				panic(err)
			}
			glInitialized = true
		}

		// GL-состояние (blend и др.) не разделяется между контекстами.
		gl.Enable(gl.BLEND)
		gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
		gl.Enable(gl.LINE_SMOOTH)

		program, err := createProgram()
		if err != nil {
			panic(err)
		}

		var vao, vbo uint32
		gl.GenVertexArrays(1, &vao)
		gl.GenBuffers(1, &vbo)

		// GetSize возвращает логический размер — то же пространство, что и CGEventGetLocation.
		winW, winH := win.GetSize()

		wins = append(wins, monitorWin{
			win:     win,
			x:       mx,
			y:       my,
			w:       winW,
			h:       winH,
			program: program,
			vao:     vao,
			vbo:     vbo,
		})
	}

	return wins
}

// updateTrail добавляет новую точку в хвост с линейной интерполяцией
// промежуточных точек при быстром движении курсора.
func updateTrail(trail []point, newX, newY float32, maxLen int) []point {
	newPt := point{x: newX, y: newY}

	if len(trail) > 0 {
		last := trail[len(trail)-1]
		d := dist(float64(newX), float64(newY), float64(last.x), float64(last.y))
		if d > 10 {
			steps := int(d / 5)
			for i := 1; i < steps; i++ {
				t := float32(i) / float32(steps)
				trail = append(trail, point{
					x: last.x + t*(newX-last.x),
					y: last.y + t*(newY-last.y),
				})
			}
		}
	}

	trail = append(trail, newPt)
	if len(trail) > maxLen {
		trail = trail[len(trail)-maxLen:]
	}
	return trail
}

// renderTrail отрисовывает хвост на конкретном мониторе.
// NDC-конвертация учитывает смещение и размер монитора в глобальных координатах,
// поэтому точки на других мониторах просто уходят за [-1,1] и обрезаются OpenGL.
func renderTrail(trail []point, mw monitorWin, lw, fadeAlpha float32) {
	gl.ClearColor(0, 0, 0, 0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	if len(trail) == 0 || fadeAlpha <= 0 {
		return
	}

	verts := make([]float32, 0, len(trail)*3)
	for i, p := range trail {
		ndcX := ((p.x - float32(mw.x)) / float32(mw.w)) * 2 - 1
		ndcY := (1 - (p.y-float32(mw.y))/float32(mw.h)) * 2 - 1

		var alpha float32
		if len(trail) == 1 {
			alpha = 1.0
		} else {
			progress := float32(i) / float32(len(trail)-1)
			alpha = 0.3 + 0.7*progress
		}
		verts = append(verts, ndcX, ndcY, alpha*fadeAlpha)
	}

	gl.BindVertexArray(mw.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, mw.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(verts)*4, gl.Ptr(verts), gl.DYNAMIC_DRAW)

	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 3*4, gl.PtrOffset(0))
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(1, 1, gl.FLOAT, false, 3*4, gl.PtrOffset(2*4))
	gl.EnableVertexAttribArray(1)

	gl.UseProgram(mw.program)
	gl.LineWidth(lw)
	gl.DrawArrays(gl.LINE_STRIP, 0, int32(len(trail)))
	gl.LineWidth(lw * 0.67)
	gl.DrawArrays(gl.LINE_STRIP, 0, int32(len(trail)))
	gl.LineWidth(lw * 0.33)
	gl.DrawArrays(gl.LINE_STRIP, 0, int32(len(trail)))
}

func main() {
	flag.Parse()

	var coords [2]C.double
	initEventTap(&coords)

	monitors := initWindows()
	defer glfw.Terminate()

	trail := make([]point, 0, *trailLength)

	// Инициализируем стартовую позицию курсора
	pos := C.getCurrentMousePosition()
	coords[0] = pos.x
	coords[1] = pos.y
	for i := 0; i < 5; i++ {
		trail = append(trail, point{x: float32(coords[0]), y: float32(coords[1])})
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-stop
		for _, mw := range monitors {
			mw.win.SetShouldClose(true)
		}
	}()

	var fadeAlpha float32 = 1.0
	frameCounter := 0

	for {
		// Выход если любое окно запросило закрытие
		shouldClose := false
		for _, mw := range monitors {
			if mw.win.ShouldClose() {
				shouldClose = true
				break
			}
		}
		if shouldClose {
			break
		}

		curX := float32(coords[0])
		curY := float32(coords[1])

		moving := len(trail) == 0 ||
			dist(float64(curX), float64(curY), float64(trail[len(trail)-1].x), float64(trail[len(trail)-1].y)) > 1

		if moving {
			fadeAlpha = 1.0
			trail = updateTrail(trail, curX, curY, *trailLength)
		} else {
			fadeAlpha -= 0.01
			if fadeAlpha < 0 {
				fadeAlpha = 0
				trail = trail[:0]
			}
		}

		if *debugMode {
			frameCounter++
			if frameCounter%60 == 0 && len(trail) > 0 {
				head := trail[len(trail)-1]
				fmt.Printf("DEBUG: frame=%d cursor=(%.0f,%.0f) head=(%.0f,%.0f) trail=%d fade=%.2f monitors=%d\n",
					frameCounter, float64(curX), float64(curY),
					float64(head.x), float64(head.y), len(trail), fadeAlpha, len(monitors))
			}
		}

		// Рендерим хвост на каждом мониторе
		for _, mw := range monitors {
			mw.win.MakeContextCurrent()
			renderTrail(trail, mw, float32(*lineWidth), fadeAlpha)
			mw.win.SwapBuffers()
		}

		glfw.PollEvents()
	}

	C.CFRunLoopStop(C.CFRunLoopGetCurrent())
	fmt.Println("Завершено.")
}
