class ProcessCfdi < ApplicationService
  def initialize(cfdis:)
    @cfdis = cfdis
  end

  def call
    @cfdis.each_with_object([]) do |cfdi, memo|
      memo << procesar_cfdi(cfdi)
    end
  end

  CFDI_KEYS = %w[Fecha FormaPago MetodoPago Moneda SubTotal TipoDeComprobante Total Version
                 Descuento].freeze
  CFDI_KEYS_CURRENCY = %w[SubTotal Total Descuento].freeze

  Emisor = Struct.new(:rfc, :nombre)
  Receptor = Struct.new(:rfc, :nombre)
  Impuesto = Struct.new(:total, :isr, :iva, :ieps, :total_retenciones, :retencion_isr, :retencion_iva)
  Cfdi = Struct.new(:file, :uuid, :emisor, :receptor, :impuestos, *(CFDI_KEYS.map { |i| i.downcase.to_sym }))

  def procesar_cfdi(file)
    doc = Nokogiri.XML(File.open(file))
    uuid = extract_uuid(doc)
    data = extract_params_comprobante(doc)
    data[0] = Date.parse(data[0])

    Cfdi.new(
      file, uuid,
      extract_emisor(doc),
      extract_receptor(doc),
      extract_taxes(doc),
      *data
    )
  end

  def extract_uuid(doc)
    doc.xpath('//*:TimbreFiscalDigital/@UUID').to_s.upcase
  end

  def extract_emisor(doc)
    Emisor.new(
      doc.xpath('//cfdi:Emisor/@Rfc').first.value,
      doc.xpath('//cfdi:Emisor/@Nombre').first&.value
    )
  end

  def extract_receptor(doc)
    Receptor.new(
      doc.xpath('//cfdi:Receptor/@Rfc').first.value,
      doc.xpath('//cfdi:Receptor/@Nombre').first&.value
    )
  end

  def extract_taxes(doc)
    isr = get_tax(doc, '001')
    iva = get_tax(doc, '002')
    ieps = get_tax(doc, '003')

    ret_isr = get_retencion(doc, '001')
    ret_iva = get_retencion(doc, '002')

    Impuesto.new(
      isr + iva + ieps,
      isr, iva, ieps,
      ret_isr + ret_iva,
      ret_isr, ret_iva
    )
  end

  def extract_params_comprobante(doc)
    CFDI_KEYS.each_with_object([]) do |key, memo_i|
      value = doc.xpath("//cfdi:Comprobante/@#{key}").first&.value
      memo_i << (CFDI_KEYS_CURRENCY.include?(key) ? value.to_d : value)
    end
  end

  def get_tax(doc, code)
    doc.xpath("/cfdi:Comprobante/cfdi:Impuestos//cfdi:Traslado[@Impuesto=#{code}]").sum(0) do |v|
      v.attr(:Importe).to_d
    end
  end

  def get_retencion(doc, code)
    doc.xpath("/cfdi:Comprobante/cfdi:Impuestos//cfdi:Retencion[@Impuesto=#{code}]").sum(0) do |v|
      v.attr(:Importe).to_d
    end
  end
end
