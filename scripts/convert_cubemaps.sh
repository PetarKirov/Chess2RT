# Convert skymaps from http://www.custommapmakers.org/skyboxes.php to
# known format.

# Assumes there are a couple of *.zip files each containing cubemap images.

find -type f -iname '*.zip' | while read f; do unzip -j "$f" -d "${f%.*}"; done
find -type f -iname '*.tga' -not -iname "*lf*" | while read f; do convert "$f" "${f%.*}.bmp"; done
find -type f -iname '*.tga' -and -iname "*lf*" | while read f; do convert "$f" -rotate 180 "${f%.*}.bmp"; done
find -type f -iname '*.jpg' -not -iname "*lf*" | while read f; do convert "$f" "${f%.*}.bmp"; done
find -type f -iname '*.jpg' -and -iname "*lf*" | while read f; do convert "$f" -rotate 180 "${f%.*}.bmp"; done

find -type f -iname '*rt*.bmp' | while read f; do mv -v "$f" "${f%/*}/posz.bmp"; done
find -type f -iname '*up*.bmp' | while read f; do mv -v "$f" "${f%/*}/posy.bmp"; done
find -type f -iname '*ft*.bmp' | while read f; do mv -v "$f" "${f%/*}/posx.bmp"; done
find -type f -iname '*lf*.bmp' | while read f; do mv -v "$f" "${f%/*}/negz.bmp"; done
find -type f -iname '*bk*.bmp' | while read f; do mv -v "$f" "${f%/*}/negx.bmp"; done
find -type f -iname '*dn*.bmp' | while read f; do mv -v "$f" "${f%/*}/negy.bmp"; done

find -type f \
   \( -iname 'readme*' -or -iname '*.txt' -or \
      -iname '*.shader' -or -iname '*.tga' -or -iname '*.jpg' \) \
   -exec rm -v {} \;
