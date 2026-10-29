import AppKit
import CoreImage

public enum PromptPayQRGenerator {
    public static func generatePayload(mobile: String) -> String {
        var cleaned = mobile.replacingOccurrences(of: "-", with: "")
        if cleaned.hasPrefix("0") {
            cleaned = "0066" + cleaned.dropFirst()
        } else if !cleaned.hasPrefix("0066") {
            cleaned = "0066" + cleaned
        }

        let targetTag = "01"
        let targetLength = String(format: "%02d", cleaned.count)
        let subTag01 = "\(targetTag)\(targetLength)\(cleaned)"

        let aid = "0016A000000677010111"
        let tag29Value = aid + subTag01
        let tag29 = String(format: "29%02d%@", tag29Value.count, tag29Value)

        let raw = "000201010211" + tag29 + "53037645802TH6304"
        let crc = calculateCRC16(raw)
        return raw + String(format: "%04X", crc)
    }

    private static func calculateCRC16(_ text: String) -> UInt16 {
        guard let data = text.data(using: .utf8) else { return 0 }
        var crc: UInt16 = 0xFFFF
        for byte in data {
            crc ^= (UInt16(byte) << 8)
            for _ in 0..<8 {
                if (crc & 0x8000) != 0 {
                    crc = ((crc << 1) ^ 0x1021) & 0xFFFF
                } else {
                    crc = (crc << 1) & 0xFFFF
                }
            }
        }
        return crc
    }

    public static func generateQRCodeImage(mobile: String, size: CGFloat = 240) -> NSImage? {
        let payload = generatePayload(mobile: mobile)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(payload.data(using: .utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
