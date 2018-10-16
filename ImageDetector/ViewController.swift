import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var label:UILabel = UILabel()
    public var text0:UILabel = UILabel()
    public var text1:UILabel = UILabel()
    
    let captureSession = AVCaptureSession()
    let output: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    var previewLayer:AVCaptureVideoPreviewLayer!

    var detecting:Bool = false
    var isPortrait:Bool = true
    public var mym = Mymodel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector:#selector(self.changedDeviceOrientation(_:)),
            name: NSNotification.Name.UIDeviceOrientationDidChange,
            object: nil)
        
        // カメラキャプチャの開始
        self.startCapture()

        let fontsize:CGFloat = 20
        
        // 緑の枠
        self.label.textColor = UIColor.green
        self.label.layer.borderColor  = UIColor.green.cgColor
        self.label.layer.borderWidth = 1.0
        self.label.layer.cornerRadius = 0
        self.view.addSubview(self.label)
        
        // テキスト背景
        self.text0.backgroundColor = UIColor(red:0.0,green:0.0,blue:0.0,alpha:0.5)
        self.text0.numberOfLines = 0
        self.text0.layer.cornerRadius = 4
        self.text0.clipsToBounds = true
        self.view.addSubview(self.text0)

        // テキスト
        self.text1.textColor = UIColor.green
        self.text1.font = UIFont.systemFont(ofSize:fontsize)
        self.text1.numberOfLines = 0
        self.view.addSubview(self.text1)

        self.setPosition() 
    }
    
    /// UIの位置を合わせる
    private func setPosition() {
        let vw:CGFloat = self.view.bounds.width
        let vh:CGFloat = self.view.bounds.height
        
        // ┌────┐
        // │    │
        // ├────┤
        // └────┘        
        var pa:CGFloat = vw * 0.10
        var lw:CGFloat = vw * 0.80
        var lx:CGFloat = pa
        var ly:CGFloat = pa
        var tw:CGFloat = lw
        var th:CGFloat = vh - (pa + lw + 20) - pa
        var tx:CGFloat = pa
        var ty:CGFloat = pa + lw + 20
        
        // ┌────┬─┐ ┌──┬───┐
        // │    │ │ │  │   │
        // └────┴─┘ └──┴───┘
        if UIDevice.current.orientation == .landscapeLeft
        || UIDevice.current.orientation == .landscapeRight {
            pa = vh * 0.10
            lw = vh * 0.80
            lx = pa
            ly = pa
            tw = vw - (pa + lw + 20) - pa
            th = lw
            tx = pa + lw + 20
            ty = pa
            if UIDevice.current.orientation == .landscapeRight {
                lx = vw - lw - pa
                tx = pa
            }
        }
        
        self.label.frame = CGRect.init(x:lx, y:ly, width:lw, height:lw)
        self.text0.frame = CGRect.init(x:tx, y:ty, width:tw, height:th)        
        self.text1.frame = self.text0.frame.offsetBy(dx: 8.0, dy: 0)

    }
    /// カメラキャプチャーの開始
    private func startCapture() {
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        
        // 入力の設定
        let captureDevice = AVCaptureDevice.default(for: .video)!
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        guard captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)
        
        // 出力の設定
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoQueue"))
        guard captureSession.canAddOutput(output) else { return }
        captureSession.addOutput(output)
        
        // プレビューの設定
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        
        // キャプチャー開始
        captureSession.startRunning()
    }

    /// カメラ回転
    @objc func changedDeviceOrientation(_ notification :Notification) {
        let videoLayer = previewLayer!
        videoLayer.frame = view.bounds

        var bori = true
        var vori:AVCaptureVideoOrientation = .portraitUpsideDown
        switch UIDevice.current.orientation {
        case .portrait:           vori = .portrait
        case .portraitUpsideDown: vori = .portraitUpsideDown
        case .landscapeLeft:      vori = .landscapeRight
        case .landscapeRight:     vori = .landscapeLeft
        default: bori = false
            break
        }

        if bori == true {
            videoLayer.connection!.videoOrientation = vori
            self.setPosition()
        }
    }
    
    /// １フレーム毎に呼ばれる
    /// AVCaptureVideoDataOutputSampleBufferDelegateを派生
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard var buffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        
        // 非同期で画像認識を実行します
        // 処理中に上書きされるのを防ぐためバッファをコピーします
        // 負荷軽減に少し待ちます
        if (self.detecting == false) {
            self.detecting = true
            DispatchQueue(label:"detecting.queue").async {
                let copyBuffer = buffer.deepcopy()
                self.mym.recognize(buffer: copyBuffer)

                var s:String = ""
                let clss = self.mym.result.clss.sorted{ $0.1 > $1.1 }
                for (key,val) in clss.prefix(5) {
                    let key2 = key.components(separatedBy: ", ")[0]
                    s += String(NSString(format: "%02d", val)) + " " + key2 + "\n"
                }
                DispatchQueue.main.async {
                    self.text1.text = s
                }

                usleep(500*1000) // ms
                self.detecting = false
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }    
}

extension CVPixelBuffer {
    func deepcopy() -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format = CVPixelBufferGetPixelFormatType(self)
        var pixelBufferCopyOptional:CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, format, nil, &pixelBufferCopyOptional)
        if let pixelBufferCopy = pixelBufferCopyOptional {
            CVPixelBufferLockBaseAddress(self, .readOnly)
            CVPixelBufferLockBaseAddress(pixelBufferCopy, .readOnly)
            let baseAddress = CVPixelBufferGetBaseAddress(self)
            let dataSize = CVPixelBufferGetDataSize(self)
            let target = CVPixelBufferGetBaseAddress(pixelBufferCopy)
            memcpy(target, baseAddress, dataSize)
            CVPixelBufferUnlockBaseAddress(pixelBufferCopy, .readOnly)
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }
        return pixelBufferCopyOptional!
    }
}

