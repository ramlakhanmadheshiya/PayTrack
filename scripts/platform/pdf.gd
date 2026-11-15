class_name Pdf
extends RefCounted
## Minimal PDF writer: one JPEG image per A4 page. Enough for sharing bills.


static func from_images(pages: Array) -> PackedByteArray:
	var out := PackedByteArray()
	var offsets: Array = []
	var w_pt := 595.0
	var h_pt := 842.0
	var n := pages.size()
	# Object numbers: 1 catalog, 2 pages, then per page: page, content, image.
	out.append_array("%PDF-1.4\n%âãÏÓ\n".to_utf8_buffer())
	var kids := []
	for i in n:
		kids.append("%d 0 R" % (3 + i * 3))
	offsets.append(out.size())
	out.append_array("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n".to_utf8_buffer())
	offsets.append(out.size())
	out.append_array(("2 0 obj\n<< /Type /Pages /Kids [%s] /Count %d >>\nendobj\n" % [" ".join(kids), n]).to_utf8_buffer())
	for i in n:
		var img: Image = pages[i]
		var jpg := img.save_jpg_to_buffer(0.9)
		var page_id := 3 + i * 3
		var content_id := page_id + 1
		var image_id := page_id + 2
		offsets.append(out.size())
		out.append_array(("%d 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] /Resources << /XObject << /Im%d %d 0 R >> >> /Contents %d 0 R >>\nendobj\n" % [page_id, int(w_pt), int(h_pt), i, image_id, content_id]).to_utf8_buffer())
		var stream := ("q %.2f 0 0 %.2f 0 0 cm /Im%d Do Q" % [w_pt, h_pt, i]).to_utf8_buffer()
		offsets.append(out.size())
		out.append_array(("%d 0 obj\n<< /Length %d >>\nstream\n" % [content_id, stream.size()]).to_utf8_buffer())
		out.append_array(stream)
		out.append_array("\nendstream\nendobj\n".to_utf8_buffer())
		offsets.append(out.size())
		out.append_array(("%d 0 obj\n<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length %d >>\nstream\n" % [image_id, img.get_width(), img.get_height(), jpg.size()]).to_utf8_buffer())
		out.append_array(jpg)
		out.append_array("\nendstream\nendobj\n".to_utf8_buffer())
	var xref := out.size()
	var total := offsets.size() + 1
	var x := "xref\n0 %d\n0000000000 65535 f \n" % total
	for o in offsets:
		x += "%010d 00000 n \n" % o
	x += "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % [total, xref]
	out.append_array(x.to_utf8_buffer())
	return out
