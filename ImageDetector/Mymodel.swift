import UIKit
import AVFoundation
import Vision
import CoreML

/*
 機械学習のモデルの結果を表示します。
 １回の結果は、すべての分類を足して100になるように出ます。
 このアプリでは、毎回結果をプラスして、20をマイナスします。
 １秒間に２回判定するので、2.5秒間何もなければゼロになります。
*/
class Mymodel {

    /// 結果
    public var result:Result = Result()
    class Result {
        public var bounds:CGRect = CGRect(x:0,y:0,width:1,height:1)
        public var clss = [String:Int]()
    }
    
    /// 画像認識の実行
    func recognize(buffer:CVImageBuffer) {
        let ciImage:CIImage = CIImage(cvPixelBuffer: buffer)
        let szImage = ciImage.extent.size

        // 画像を切り取る
        let w:CGFloat = szImage.height*0.8
        let p:CGFloat = szImage.height*0.1
        self.result.bounds = CGRect(x:p, y:p, width:w, height:w)        
        let ciCropImage = ciImage.cropImage(rect: self.result.bounds)
        
        let handler = VNImageRequestHandler(ciImage: ciCropImage)
        do {
            try handler.perform([self.requestMymodel])
        } catch {
            print(error)
        }
    }
    
    // 学習モデルリクエスト
    lazy var requestMymodel: VNCoreMLRequest = {
        do {
            var model: VNCoreMLModel? = nil
            model = try VNCoreMLModel(for: Inceptionv3().model) // ここを自作モデルに入れ替える
            return VNCoreMLRequest(model: model!, completionHandler: self.completeMymodel)
        } catch {
            fatalError("can't load Vision ML model: \(error)")
        }
    }()

    // 学習モデル結果
    func completeMymodel(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation] else { 
            return 
        }
        // 結果の上位3つを100%にして足す
        for observation in results.prefix(3) {
            let conf = (Int)(observation.confidence * 100.0)
            if let val = self.result.clss[observation.identifier] {
                self.result.clss[observation.identifier] = val + conf
            } else {
                self.result.clss[observation.identifier] = conf
            }
        }
        // 毎回結果から引く
        for (key, val) in self.result.clss {
            let v = val - 20
            if v<0 { self.result.clss[key] = nil }
            else if v>99 { self.result.clss[key] = 99 }
            else { self.result.clss[key] = v }
        }
    }
}
