class DownloadsController < ApplicationController
  def received
    @cfdis = ProcessCfdi.call(cfdis: Dir.glob('data/received/*.xml')).find_all do |i|
               i.subtotal > 10
             end.reject { |i| %w[BSM970519DU8 NFI3406305T0 CPR140730DI0 GGB080116EZ0].include?(i.emisor.rfc) }
  end

  def sent
    @cfdis = ProcessCfdi.call(cfdis: Dir.glob('data/sent/*.xml'))
  end
end
